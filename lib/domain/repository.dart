import 'dart:convert';

import 'models.dart';

/// Parses a character backup or shared character. Throws [FormatException]
/// when it is not one, or comes from a newer version of the app.
Character decodeCharacterJson(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const FormatException('Not a character file');
  }
  if (decoded is! Map) throw const FormatException('Not a character file');
  final map = decoded.cast<String, Object?>();
  final version = (map['schemaVersion'] as num?)?.toInt() ?? 1;
  if (version > 1) {
    throw FormatException('Unsupported schema version $version');
  }
  if (map['id'] is! String || map['name'] is! String) {
    throw const FormatException('Not a character file');
  }
  try {
    return Character.fromJson(map);
  } on TypeError {
    throw const FormatException('Not a character file');
  }
}

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

  /// Saves a character received from another device. With [asCopy] it gets
  /// a new id. Otherwise it keeps its id, and if a character with that id is
  /// already here it is replaced (and the replacement can be undone).
  Future<Character> receive(Character c, {bool asCopy = false});
}
