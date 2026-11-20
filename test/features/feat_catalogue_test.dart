import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/data/character_files.dart';
import 'package:jjs_character_tracker/data/feat_library.dart';
import 'package:jjs_character_tracker/domain/feat_catalog.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/features/feats/feat_catalogue_screen.dart';
import 'package:jjs_character_tracker/features/feats/feat_picker.dart';

void main() {
  late Directory dir;
  late File file;
  late FeatLibrary lib;
  String? exported;

  setUp(() {
    resetFeatCatalogForTests();
    exported = null;
    dir = Directory.systemTemp.createTempSync('featcat');
    file = File('${dir.path}/feats.json');
    lib = FeatLibrary(locate: () async => file);
  });
  tearDown(() => dir.deleteSync(recursive: true));

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
          RepositoryProvider<FeatLibrary?>.value(value: lib),
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
          home: const FeatCatalogueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const two =
      '{"feats":[{"id":"a","name":"Alert","text":"+5 initiative"},'
      '{"id":"b","name":"Tough","prerequisite":"None"}]}';

  testWidgets('empty catalogue shows a hint and disables export', (t) async {
    await openEditor(t);
    expect(find.textContaining('catalogue is empty'), findsOneWidget);
    final export = t.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.file_download_outlined),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('lists feats and filters by search', (t) async {
    await openEditor(t, seed: two);
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Tough'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'tou');
    await t.pump();
    expect(find.text('Alert'), findsNothing);
    expect(find.text('Tough'), findsOneWidget);
  });

  testWidgets('adds a feat, saved to the file', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Add feat'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Lucky');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(featCatalog.map((f) => f.name), ['Alert', 'Tough', 'Lucky']);
    expect(file.readAsStringSync(), contains('Lucky'));
  });

  testWidgets('rejects a duplicate name', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Add feat'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Name'), ' alert ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.textContaining('already has a feat'), findsOneWidget);
    expect(featCatalog, hasLength(2));
  });

  testWidgets('edits a feat in place, keeping its id', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Tough'));
    await t.pumpAndSettle();
    final name = find.widgetWithText(TextField, 'Name');
    await t.enterText(name, 'Tougher');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(featCatalog.map((f) => f.id), ['a', 'b']);
    expect(featCatalog.last.name, 'Tougher');
    expect(featCatalog.last.prerequisite, 'None');
  });

  testWidgets('delete removes the feat', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.text('Alert'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await settle(t);
    expect(featCatalog.map((f) => f.id), ['b']);
  });

  testWidgets('export hands over a file Import feats accepts', (t) async {
    await openEditor(t, seed: two);
    await t.tap(find.byTooltip('Export catalogue'));
    await settle(t);
    expect((jsonDecode(exported!) as Map)['feats'], hasLength(2));
    expect(parseFeatCatalog(exported!).map((f) => f.name), ['Alert', 'Tough']);
  });

  group('FeatPicker', () {
    Future<Feat?> pick(WidgetTester t, {Set<String> taken = const {}}) async {
      Feat? picked;
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await showModalBottomSheet<Feat>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => FeatPicker(taken: taken),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return picked;
    }

    testWidgets('shows a hint when no feats are imported', (t) async {
      await pick(t);
      expect(find.textContaining('No feats imported yet'), findsOneWidget);
      expect(find.text('Create a custom feat'), findsOneWidget);
    });

    testWidgets('a catalogue feat is previewed, then added', (t) async {
      setFeatCatalog(parseFeatCatalog(two));
      await pick(t);
      await t.tap(find.text('Alert'));
      await t.pumpAndSettle();
      expect(find.text('+5 initiative'), findsOneWidget);
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();
      // The sheet closed with the feat.
      expect(find.text('Search feats'), findsNothing);
    });

    testWidgets('a feat the character has cannot be added again', (t) async {
      setFeatCatalog(parseFeatCatalog(two));
      await pick(t, taken: {'alert'});
      await t.tap(find.text('Alert'));
      await t.pumpAndSettle();
      expect(find.text('Add'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('a custom feat is created and returned', (t) async {
      await pick(t);
      await t.tap(find.text('Create a custom feat'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Name'), 'Homebrew');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Create a custom feat'), findsNothing);
    });
  });
}
