import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/data/character_files.dart';
import 'package:jjs_character_tracker/data/spell_library.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';
import 'package:jjs_character_tracker/features/spells/spell_catalogue_screen.dart';

void main() {
  late Directory dir;
  late File file;
  late SpellLibrary lib;
  String? exported;

  setUp(() {
    resetSpellCatalogForTests();
    exported = null;
    dir = Directory.systemTemp.createTempSync('catalogue');
    file = File('${dir.path}/spells.json');
    lib = SpellLibrary(locate: () async => file);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// File IO finishes on the real event loop, one step per round trip, so
  /// alternate between letting it run and pumping the widgets.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester, {String? seed}) async {
    if (seed != null) await tester.runAsync(() => lib.import(seed));
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SpellLibrary?>.value(value: lib),
          RepositoryProvider<CharacterFiles>.value(
            value: CharacterFiles(
              save: (name, json) async {
                exported = json;
                return true;
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const SpellCatalogueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const two =
      '{"spells":[{"id":"a","name":"Alpha","level":0},'
      '{"id":"b","name":"Beta","level":3,"school":"Evocation"}]}';

  testWidgets('empty catalogue shows a hint and disables export', (t) async {
    await openEditor(t);
    expect(find.textContaining('catalogue is empty'), findsOneWidget);
    final export = t.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.file_download_outlined),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('lists spells and filters by search and level', (t) async {
    await openEditor(t, seed: two);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'bet');
    await t.pump();
    expect(find.text('Alpha'), findsNothing);
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('Cantrip'));
    await t.pump();
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('adds a spell, saved and used for suggestions', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Add spell'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Name'), 'Gamma');
    await t.tap(find.text('Add').first);
    await settle(t);
    expect(spellCatalog.map((s) => s.name), ['Alpha', 'Beta', 'Gamma']);
    expect(find.text('Gamma'), findsOneWidget);
    expect(file.readAsStringSync(), contains('Gamma'));
  });

  testWidgets('rejects a duplicate name', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Add spell'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Name'), ' alpha ');
    await t.tap(find.text('Add').first);
    await t.pumpAndSettle();
    expect(find.textContaining('already has a spell'), findsOneWidget);
    expect(spellCatalog, hasLength(2));
  });

  testWidgets('edits a spell in place, keeping its id', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    final name = find.widgetWithText(TextFormField, 'Name');
    expect(t.widget<TextFormField>(name).controller!.text, 'Beta');
    await t.enterText(name, 'Beta II');
    await t.tap(find.text('Save').first);
    await settle(t);
    expect(spellCatalog.map((s) => s.id), ['a', 'b']);
    expect(spellCatalog.last.name, 'Beta II');
    expect(spellCatalog.last.school, 'Evocation');
    expect(spellCatalog.last.level, 3);
  });

  testWidgets('a spell sharing its name with another can still be edited', (
    t,
  ) async {
    // Import spells does not reject repeated names, so a catalogue can hold
    // two spells called Light. Saving one without renaming it must work.
    await openEditor(
      t,
      seed:
          '{"spells":[{"id":"a","name":"Light","level":0},'
          '{"id":"b","name":"Light","level":0}]}',
    );
    await t.tap(find.text('Light').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Save').first);
    await settle(t);
    expect(find.textContaining('already has a spell'), findsNothing);
    expect(find.text('Edit spell'), findsNothing);
    expect(spellCatalog.map((s) => s.id), ['a', 'b']);
  });

  testWidgets('delete asks first, then removes the spell', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.byTooltip('Delete Alpha'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(spellCatalog, hasLength(2));
    await t.tap(find.byTooltip('Delete Alpha'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await settle(t);
    expect(spellCatalog.map((s) => s.id), ['b']);
    // Deleting the last one leaves a valid, empty catalogue.
    await t.tap(find.byTooltip('Delete Beta'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await settle(t);
    expect(spellCatalog, isEmpty);
    expect(find.textContaining('catalogue is empty'), findsOneWidget);
    resetSpellCatalogForTests();
    await t.runAsync(lib.load);
    expect(spellCatalog, isEmpty);
  });

  testWidgets('export hands over a file Import spells accepts', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.byTooltip('Export catalogue'));
    await settle(t);
    expect(exported, isNotNull);
    expect((jsonDecode(exported!) as Map)['spells'], hasLength(2));
    expect(parseSpellCatalog(exported!).map((s) => s.name), ['Alpha', 'Beta']);
    expect(find.textContaining('Exported'), findsOneWidget);
  });
}
