import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/actions.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/repository.dart';
import 'package:uuid/uuid.dart';

Character make() => createCharacter(
  name: 'Test',
  race: 'Elf',
  className: 'Sorcerer',
  level: 3,
  abilities: standardArray,
);

void main() {
  late AppDatabase db;
  late DriftCharacterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
  });
  tearDown(() => db.close());

  test('create, read and watch', () async {
    final c = make();
    await repo.create(c);
    expect((await repo.get(c.id))!.name, 'Test');
    expect(await repo.watchAll().first, hasLength(1));
  });

  test(
    'apply writes the change and a log entry together; undo restores',
    () async {
      final c = make();
      await repo.create(c);
      final r = applyDamage(c, 5);
      await repo.apply(
        before: c,
        after: r.character,
        type: 'HpDamageApplied',
        description: r.description,
      );
      expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent - 5);

      final log = await repo.watchLog(c.id).first;
      expect(log.first.type, 'HpDamageApplied');
      expect(log.first.undoable, isTrue);

      final undone = await repo.undoLast(c.id);
      expect(undone, contains('damage'));
      expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent);

      final after = await repo.watchLog(c.id).first;
      expect(after.first.type, 'undo');
      expect(after.first.undoable, isFalse);
      // Nothing left to undo.
      expect(await repo.undoLast(c.id), isNull);
    },
  );

  test('repeated undo walks back through history', () async {
    var c = make();
    await repo.create(c);
    for (final amount in [2, 3]) {
      final r = applyDamage(c, amount);
      await repo.apply(
        before: c,
        after: r.character,
        type: 'x',
        description: 'd$amount',
      );
      c = r.character;
    }
    await repo.undoLast(c.id);
    expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent + 3);
    await repo.undoLast(c.id);
    expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent + 5);
  });

  test('export and import make a copy', () async {
    final c = make();
    await repo.create(c);
    final json = await repo.exportJson(c.id);
    final copy = await repo.importJson(json);
    expect(copy.id, isNot(c.id));
    expect(copy.name, c.name);
    expect(await repo.watchAll().first, hasLength(2));
  });

  test('import rejects junk and newer schemas', () async {
    expect(() => repo.importJson('[]'), throwsFormatException);
    expect(
      () => repo.importJson('{"schemaVersion": 99}'),
      throwsFormatException,
    );
  });

  test('delete removes the character and its log', () async {
    final c = make();
    await repo.create(c);
    await repo.delete(c.id);
    expect(await repo.get(c.id), isNull);
    expect(await repo.watchLog(c.id).first, isEmpty);
  });

  test('log stays bounded', () async {
    var c = make();
    await repo.create(c);
    for (var i = 0; i < 520; i++) {
      final r = setNotes(c, 'n$i');
      await repo.apply(
        before: c,
        after: r.character,
        type: 'x',
        description: 'd$i',
      );
      c = r.character;
    }
    final rows = await db.select(db.logEntries).get();
    expect(rows.length, lessThanOrEqualTo(500));
  });

  test('receive keeps the id, replaces undoably, or saves a copy', () async {
    final c = make();
    // New to this device: keeps the sender's id.
    expect((await repo.receive(c)).id, c.id);
    expect(await repo.watchAll().first, hasLength(1));

    // Same id again: replaces, and the replacement can be undone.
    final changed = applyDamage(c, 4).character;
    await repo.receive(changed);
    expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent - 4);
    expect(await repo.watchAll().first, hasLength(1));
    expect(await repo.undoLast(c.id), contains('another device'));
    expect((await repo.get(c.id))!.hpCurrent, c.hpCurrent);

    // Or keep both.
    final copy = await repo.receive(changed, asCopy: true);
    expect(copy.id, isNot(c.id));
    expect(Uuid.isValidUUID(fromString: copy.id), isTrue);
    expect(await repo.watchAll().first, hasLength(2));
  });

  test('decodeCharacterJson rejects things that are not characters', () {
    expect(() => decodeCharacterJson('not json'), throwsFormatException);
    expect(() => decodeCharacterJson('{"name": "x"}'), throwsFormatException);
    expect(
      () =>
          decodeCharacterJson('{"id": "a", "name": "x", "hpCurrent": "lots"}'),
      throwsFormatException,
    );
  });
}
