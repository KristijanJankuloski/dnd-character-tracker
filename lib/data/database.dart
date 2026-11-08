import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// One row per character. Rarely-queried nested data (items, effects,
/// recharge rules) lives in the JSON column. Frequently updated or queried
/// things (log, summary fields) have their own columns and tables.
@DataClassName('CharacterRow')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LogRow')
class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get characterId =>
      text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get description => text()();

  /// Character JSON before and after the change; undo restores `before`.
  TextColumn get before => text().nullable()();
  TextColumn get after => text().nullable()();
  BoolColumn get undoable => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
}

/// A deleted character, kept so that deleting it on one device deletes it on
/// the others instead of the other device sending it back.
@DataClassName('TombstoneRow')
class Tombstones extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Devices this one has been paired with.
@DataClassName('PeerRow')
class SyncPeers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Shared secret, base64.
  TextColumn get key => text()();
  IntColumn get pairedAt => integer()();
  IntColumn get lastSyncAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What this device and a peer last agreed on for each character, each time in
/// its own device's clock.
@DataClassName('BaseRow')
class SyncBases extends Table {
  TextColumn get peerId => text()();
  TextColumn get characterId => text()();
  IntColumn get localTime => integer()();
  IntColumn get remoteTime => integer()();

  @override
  Set<Column> get primaryKey => {peerId, characterId};
}

/// Small key/value settings (this device's sync id and name).
@DataClassName('SettingRow')
class SyncSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Characters,
    LogEntries,
    Tombstones,
    SyncPeers,
    SyncBases,
    SyncSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'jjs_character_tracker'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(tombstones);
        await m.createTable(syncPeers);
        await m.createTable(syncBases);
        await m.createTable(syncSettings);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
