import 'dart:convert';

import 'models.dart';
import 'sync.dart';

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

  // --- Syncing with nearby devices -------------------------------------

  /// Gives every character whose id is not a UUID (the early `char-…` ids) a
  /// new UUID, so ids from different devices can never collide. Returns how
  /// many were changed.
  Future<int> assignLegacyIds();

  /// Summaries of every character and every deleted character, for syncing.
  Future<List<SyncSummary>> syncSummaries();

  /// The character as JSON for sending to another device, or null if it is
  /// not here.
  Future<String?> exportForSync(String id);

  /// Saves a character received through sync. [remoteTime] is its last-change
  /// time on the other device and [skewMs] how far that device's clock is
  /// ahead of this one, so the time kept here means the same thing as the
  /// times of local edits. Returns the time it was stored with.
  Future<int> applySynced(Character c, {required int remoteTime, int skewMs});

  /// Deletes a character because the other device deleted it. Returns the
  /// local deletion time, or null if the character was already gone.
  Future<int> applySyncedDelete(
    String id, {
    required String name,
    required int remoteTime,
    int skewMs,
  });
}
