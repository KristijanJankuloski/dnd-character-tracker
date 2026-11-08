import 'models.dart';

class LogEntry {
  const LogEntry({
    required this.id,
    required this.characterId,
    required this.type,
    required this.description,
    required this.createdAt,
    required this.undoable,
  });
  final int id;
  final String characterId;
  final String type;
  final String description;
  final DateTime createdAt;

  /// True until it is undone, and false for undo entries themselves.
  final bool undoable;
}

/// What the presentation layer knows about storage.
abstract class CharacterRepository {
  Stream<List<Character>> watchAll();
  Stream<Character?> watch(String id);
  Future<Character?> get(String id);

  /// Inserts a new character.
  Future<void> create(Character c);

  /// Saves without a log entry (notes, view settings).
  Future<void> save(Character c);

  /// Saves [after] and writes a log entry in the same transaction.
  Future<void> apply({
    required Character before,
    required Character after,
    required String type,
    required String description,
  });

  Future<void> delete(String id);
  Stream<List<LogEntry>> watchLog(String characterId);

  /// Restores the snapshot before the latest undoable entry. Returns its
  /// description, or null if there was nothing to undo.
  Future<String?> undoLast(String characterId);

  Future<String> exportJson(String id);
  Future<Character> importJson(String json);
}
