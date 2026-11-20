import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/app.dart';
import 'package:jjs_character_tracker/data/character_files.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';

import '../helpers/srd_catalog.dart';

void main() {
  setUpAll(loadTestSpellCatalog);

  late DriftCharacterRepository repo;

  Future<void> importVia(WidgetTester tester, String? text) async {
    final db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
    await tester.pumpWidget(
      DnDApp(
        repository: repo,
        characterFiles: CharacterFiles(pick: () async => text),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Import character'), findsOneWidget);
    await tester.tap(find.text('Import character'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('Import character loads a valid file', (tester) async {
    final src = createCharacter(
      name: 'Ruin King',
      race: 'Tiefling',
      className: 'Sorcerer',
      level: 5,
      abilities: standardArray,
    );
    final json = await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      final r = DriftCharacterRepository(db);
      await r.create(src);
      final out = await r.exportJson(src.id);
      await db.close();
      return out;
    });
    await importVia(tester, json);
    expect(find.text('Imported Ruin King.'), findsOneWidget);
  });

  testWidgets('Import character explains a bad file', (tester) async {
    await importVia(tester, '[]');
    expect(find.text('Character file not imported'), findsOneWidget);
    expect(find.textContaining('Not a character file'), findsOneWidget);
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    await importVia(tester, null);
    expect(find.text('Character file not imported'), findsNothing);
    expect(find.textContaining('Imported'), findsNothing);
  });

  test('fileNameFor strips characters that are unsafe in file names', () {
    expect(CharacterFiles.fileNameFor('Ruin King'), 'Ruin King');
    expect(CharacterFiles.fileNameFor('a/b:c*?'), 'abc');
    expect(CharacterFiles.fileNameFor('  '), 'character');
  });
}
