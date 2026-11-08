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

@DriftDatabase(tables: [Characters, LogEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'jjs_character_tracker'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
