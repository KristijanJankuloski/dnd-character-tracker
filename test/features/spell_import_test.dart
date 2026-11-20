import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/app.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/data/spell_library.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';

void main() {
  late Directory dir;

  setUp(() {
    resetSpellCatalogForTests();
    dir = Directory.systemTemp.createTempSync('spells');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> importVia(WidgetTester tester, String? text) async {
    final db = AppDatabase(NativeDatabase.memory());
    final lib = SpellLibrary(
      locate: () async => File('${dir.path}/spells.json'),
      pick: () async => text,
    );
    await tester.pumpWidget(
      DnDApp(repository: DriftCharacterRepository(db), spellLibrary: lib),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Import spells'), findsOneWidget);
    await tester.tap(find.text('Import spells'));
    // File IO finishes on the real event loop, one step per round trip, so
    // alternate between letting it run and pumping the widgets.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('Import spells loads a valid file', (tester) async {
    await importVia(
      tester,
      '{"spells":[{"id":"a","name":"A","level":1}]}',
    );
    expect(spellCatalog, hasLength(1));
    expect(find.textContaining('Imported 1 spell'), findsOneWidget);
  });

  testWidgets('Import spells shows the errors for a bad file', (tester) async {
    await importVia(tester, '{"spells":[{"id":"a"}]}');
    expect(spellCatalog, isEmpty);
    expect(find.text('Spell file not imported'), findsOneWidget);
    expect(find.textContaining('"name"'), findsOneWidget);
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    await importVia(tester, null);
    expect(spellCatalog, isEmpty);
    expect(find.text('Spell file not imported'), findsNothing);
  });
}
