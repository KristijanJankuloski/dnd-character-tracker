import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/repository.dart';
import 'database.dart';

/// Drift-backed repository. Drift classes never leave this file.
class DriftCharacterRepository implements CharacterRepository {
  DriftCharacterRepository(this._db);
  final AppDatabase _db;

  static const int _maxLogEntries = 500;

  Character _decode(String json) =>
      Character.fromJson((jsonDecode(json) as Map).cast());
  String _encode(Character c) => jsonEncode(c.toJson());

  @override
  Stream<List<Character>> watchAll() {
    final q = _db.select(_db.characters)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return q.watch().map((rows) => rows.map((r) => _decode(r.json)).toList());
  }

  @override
  Stream<Character?> watch(String id) {
    final q = _db.select(_db.characters)..where((t) => t.id.equals(id));
    return q.watchSingleOrNull().map((r) => r == null ? null : _decode(r.json));
  }

  @override
  Future<Character?> get(String id) async {
    final r = await (_db.select(
      _db.characters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _decode(r.json);
  }

  @override
  Future<void> create(Character c) async {
    await _db.transaction(() async {
      await _db
          .into(_db.characters)
          .insert(
            CharactersCompanion.insert(
              id: c.id,
              name: c.name,
              summary: Value('${c.race} ${c.classLine}'),
              json: _encode(c),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await _db
          .into(_db.logEntries)
          .insert(
            LogEntriesCompanion.insert(
              characterId: c.id,
              type: 'created',
              description: 'Created ${c.name}',
              after: Value(_encode(c)),
              undoable: const Value(false),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    });
  }

  @override
  Future<void> save(Character c) => _save(c);

  Future<void> _save(Character c) =>
      (_db.update(_db.characters)..where((t) => t.id.equals(c.id))).write(
        CharactersCompanion(
          name: Value(c.name),
          summary: Value('${c.race} ${c.classLine}'),
          json: Value(_encode(c)),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  @override
  Future<void> apply({
    required Character before,
    required Character after,
    required String type,
    required String description,
  }) => _db.transaction(() async {
    await _save(after);
    await _db
        .into(_db.logEntries)
        .insert(
          LogEntriesCompanion.insert(
            characterId: after.id,
            type: type,
            description: description,
            before: Value(_encode(before)),
            after: Value(_encode(after)),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    // Keep the log bounded.
    final count =
        await (_db.selectOnly(_db.logEntries)
              ..addColumns([_db.logEntries.id.count()])
              ..where(_db.logEntries.characterId.equals(after.id)))
            .map((r) => r.read(_db.logEntries.id.count()) ?? 0)
            .getSingle();
    if (count > _maxLogEntries) {
      await _db.customUpdate(
        'DELETE FROM log_entries WHERE character_id = ? AND id IN '
        '(SELECT id FROM log_entries WHERE character_id = ? ORDER BY id ASC LIMIT ?)',
        variables: [
          Variable.withString(after.id),
          Variable.withString(after.id),
          Variable.withInt(count - _maxLogEntries),
        ],
        updates: {_db.logEntries},
      );
    }
  });

  @override
  Future<void> delete(String id) async {
    await (_db.delete(
      _db.logEntries,
    )..where((t) => t.characterId.equals(id))).go();
    await (_db.delete(_db.characters)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<LogEntry>> watchLog(String characterId) {
    final q = _db.select(_db.logEntries)
      ..where((t) => t.characterId.equals(characterId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(200);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          LogEntry(
            id: r.id,
            characterId: r.characterId,
            type: r.type,
            description: r.description,
            createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
            undoable: r.undoable && r.before != null,
          ),
      ],
    );
  }

  @override
  Future<String?> undoLast(String characterId) => _db.transaction(() async {
    final entry =
        await (_db.select(_db.logEntries)
              ..where(
                (t) =>
                    t.characterId.equals(characterId) & t.undoable.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (entry == null || entry.before == null) return null;
    final current = await get(characterId);
    // Notes and view settings are saved without a log entry, so keep what is
    // current instead of rolling them back with the snapshot.
    final snapshot = _decode(entry.before!);
    final restored = current == null
        ? snapshot
        : snapshot.copyWith(
            notes: current.notes,
            compactMode: current.compactMode,
          );
    await _save(restored);
    await (_db.update(_db.logEntries)..where((t) => t.id.equals(entry.id)))
        .write(const LogEntriesCompanion(undoable: Value(false)));
    await _db
        .into(_db.logEntries)
        .insert(
          LogEntriesCompanion.insert(
            characterId: characterId,
            type: 'undo',
            description: 'Undid: ${entry.description}',
            before: Value(current == null ? null : _encode(current)),
            after: Value(_encode(restored)),
            undoable: const Value(false),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    return entry.description;
  });

  @override
  Future<String> exportJson(String id) async {
    final c = await get(id);
    if (c == null) throw StateError('Character $id not found');
    return const JsonEncoder.withIndent('  ').convert(c.toJson());
  }

  @override
  Future<Character> importJson(String json) async {
    final c = decodeCharacterJson(json);
    // Import as a copy so it never overwrites an existing character.
    final copy = _withId(c, const Uuid().v4());
    await create(copy);
    return copy;
  }

  @override
  Future<Character> receive(Character c, {bool asCopy = false}) async {
    if (asCopy) {
      final copy = _withId(c, const Uuid().v4());
      await create(copy);
      return copy;
    }
    final existing = await get(c.id);
    if (existing == null) {
      await create(c);
    } else {
      await apply(
        before: existing,
        after: c,
        type: 'received',
        description: 'Replaced with ${c.name} from another device',
      );
    }
    return c;
  }

  Character _withId(Character c, String id) =>
      Character.fromJson({...c.toJson(), 'id': id});
}
