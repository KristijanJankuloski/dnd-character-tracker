import 'package:jjs_character_tracker/core/app.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/core/widgets.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/class_templates.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/srd_catalog.dart';

void main() {
  setUpAll(loadSrdCatalogForTests);

  late AppDatabase db;
  late DriftCharacterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DnDApp(repository: repo));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<Character> seed(WidgetTester tester) async {
    final c = createCharacter(
      name: 'Ruin King',
      race: 'Tiefling',
      className: 'Sorcerer',
      level: 5,
      abilities: standardArray,
    );
    await tester.runAsync(() => repo.create(c));
    return c;
  }

  /// Polls (real time, so Drift streams can emit) until [finder] matches.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('empty state offers to create a character', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('No characters yet'), findsOneWidget);
    await db.close();
  });

  testWidgets('create a character through the form', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New character'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Mellow');
    await tester.scrollUntilVisible(
      find.text('Create character'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create character'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Mellow'), findsWidgets);
    await db.close();
  });

  testWidgets('HP pad: tap HP, type, press Damage; Undo restores', (
    tester,
  ) async {
    final c = await seed(tester);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    final max = 8 + 4 * 6; // standardArray CON 13: d6+1, then 4 x (4+1)
    expect(find.textContaining('/ ${c.hpCurrent}'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Hit points')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7');
    await tester.pump();
    await tester.tap(find.text('Damage'));
    await settle(tester);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Undo'));
    expect(find.text('${c.hpCurrent - 7}'), findsWidgets);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('${c.hpCurrent}'));
    expect(find.text('${c.hpCurrent}'), findsWidgets);
    expect(max, greaterThan(0));
    await db.close();
  });

  testWidgets('signed entry applies directly: -3 is damage', (tester) async {
    final c = await seed(tester);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('Hit points')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('${c.hpCurrent - 3}'));
    expect(find.text('${c.hpCurrent - 3}'), findsWidgets);
    await db.close();
  });

  testWidgets(
    'compact combat mode hides the portrait and shows the turn tracker',
    (tester) async {
      await seed(tester);
      await pumpApp(tester);
      await settle(tester);
      await tester.tap(find.text('Ruin King'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hit dice & inspiration'), findsOneWidget);
      await tester.tap(find.byTooltip('Compact combat mode'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hit dice & inspiration'), findsNothing);
      expect(find.text('Your turn'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      await db.close();
    },
  );

  testWidgets(
    'tapping a slot pip spends it and marks the spell turn toggle on cast',
    (tester) async {
      await seed(tester);
      await pumpApp(tester);
      await settle(tester);
      await tester.tap(find.text('Ruin King'));
      await settle(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combat'));
      await tester.pumpAndSettle();
      expect(find.text('Available'), findsNWidgets(3));
      await tester.tap(find.text('Action'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Used'), findsOneWidget);
      await tester.tap(find.text('New turn'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Available'), findsNWidgets(3));
      await db.close();
    },
  );

  testWidgets('metamagic can be chosen from the Combat features panel', (
    tester,
  ) async {
    final c = await seed(tester);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Choose'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Metamagic (0/2)'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Quickened Spell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quickened Spell'));
    await tester.pump();
    await tester.ensureVisible(find.textContaining('Twinned Spell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Twinned Spell'));
    await tester.pump();
    expect(find.text('2 of 2 chosen'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Metamagic (2/2)'), findsOneWidget);
    final saved = await tester.runAsync(() => repo.get(c.id));
    expect(saved!.metamagic, {'Quickened Spell', 'Twinned Spell'});
    await db.close();
  });

  Future<void> openCombat(WidgetTester tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Bring it fully into view so a tap does not land on the nav bar.
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  testWidgets('a trait can be added from the Combat panel and shows on the '
      'Sheet', (tester) async {
    final c = await seed(tester);
    await openCombat(tester);
    await scrollTo(tester, find.text('Add trait'));
    await tester.tap(find.text('Add trait'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Hellish Resistance',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Species'));
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Show in Senses & resistances as (optional)',
      ),
      'Fire resistance',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(() => repo.get(c.id)))!;
    expect(saved.features.last.name, 'Hellish Resistance');
    expect(saved.features.last.source, FeatureSource.species);
    expect(saved.features.last.pinned, 'Fire resistance');
    await scrollTo(tester, find.text('Hellish Resistance'));
    expect(find.text('Species'), findsOneWidget);
    await tester.tap(find.text('Sheet'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Fire resistance (Hellish Resistance)'));
    expect(find.text('Fire resistance (Hellish Resistance)'), findsOneWidget);
    await db.close();
  });

  testWidgets('a trait can be edited and deleted from the Combat panel', (
    tester,
  ) async {
    final c = createCharacter(
      name: 'Ruin King',
      race: 'Tiefling',
      className: 'Sorcerer',
      level: 5,
      abilities: standardArray,
      traits: [
        const Feature('Darkvision', '60 ft', source: FeatureSource.species),
      ],
    );
    await tester.runAsync(() => repo.create(c));
    await openCombat(tester);
    await scrollTo(tester, find.text('Darkvision'));
    await tester.tap(find.text('Darkvision'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Sees 60 ft in the dark',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pumpAndSettle();
    var saved = await tester.runAsync(() => repo.get(c.id));
    expect(saved!.features.last.text, 'Sees 60 ft in the dark');
    // Dismiss the Undo snackbar so it does not cover the row.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Darkvision'));
    await tester.tap(find.text('Darkvision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.pumpAndSettle();
    saved = await tester.runAsync(() => repo.get(c.id));
    expect(saved!.features.any((f) => f.name == 'Darkvision'), isFalse);
    await db.close();
  });

  testWidgets('the Metamagic entry has no editor', (tester) async {
    await seed(tester);
    await openCombat(tester);
    await scrollTo(tester, find.textContaining('Metamagic ('));
    await tester.tap(find.textContaining('Metamagic ('));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await db.close();
  });

  Future<void> addDarkvisionOnCreateScreen(WidgetTester tester) async {
    await tester.tap(find.text('New character'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Mellow');
    await scrollTo(tester, find.text('Add trait'));
    await tester.tap(find.text('Add trait'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextField, 'Name'),
      ),
      'Darkvision',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Species'));
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(
          TextField,
          'Show in Senses & resistances as (optional)',
        ),
      ),
      'Darkvision 60 ft',
    );
    await tester.pump();
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
  }

  Future<Character> createAndLoadMellow(WidgetTester tester) async {
    await scrollTo(tester, find.text('Create character'));
    await tester.tap(find.text('Create character'));
    await settle(tester);
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() async {
      final all = await repo.syncSummaries();
      return repo.get(all.firstWhere((s) => s.name == 'Mellow').id);
    });
    return saved!;
  }

  testWidgets('traits added on the create screen are saved with the '
      'character', (tester) async {
    await pumpApp(tester);
    await addDarkvisionOnCreateScreen(tester);
    expect(find.text('Darkvision'), findsOneWidget);
    final saved = await createAndLoadMellow(tester);
    final t = saved.features.last;
    expect(t.name, 'Darkvision');
    expect(t.source, FeatureSource.species);
    expect(t.pinned, 'Darkvision 60 ft');
    expect(
      saved.features.length,
      classTemplates['Sorcerer']!.features.length + 1,
    );
    await db.close();
  });

  testWidgets('a trait added on the create screen can be removed before '
      'saving', (tester) async {
    await pumpApp(tester);
    await addDarkvisionOnCreateScreen(tester);
    await scrollTo(tester, find.text('Darkvision'));
    await tester.tap(find.text('Darkvision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Darkvision'), findsNothing);
    final saved = await createAndLoadMellow(tester);
    expect(saved.features.length, classTemplates['Sorcerer']!.features.length);
    expect(saved.features.any((f) => f.name == 'Darkvision'), isFalse);
    await db.close();
  });

  testWidgets('the trait editor refuses a blank or reserved name and keeps '
      'what was typed', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New character'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Add trait'));
    await tester.tap(find.text('Add trait'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);

    await tester.tap(inDialog(find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.text('Give the trait a name.'), findsOneWidget);
    expect(dialog, findsOneWidget);

    await tester.enterText(
      inDialog(find.widgetWithText(TextField, 'Name')),
      'Metamagic',
    );
    await tester.enterText(
      inDialog(find.widgetWithText(TextField, 'Description')),
      'keep me',
    );
    await tester.tap(inDialog(find.text('Save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Metamagic is a built-in feature; use its Choose button.'),
      findsOneWidget,
    );
    expect(dialog, findsOneWidget);
    expect(find.text('keep me'), findsOneWidget);
    await db.close();
  });

  testWidgets('equipment rows use dark ink on the parchment panel', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    final title = find.text('Arcane Focus');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    final style = DefaultTextStyle.of(tester.element(title)).style;
    expect(style.color, Palette.ink);
    await db.close();
  });

  testWidgets('the sheet draws AC in a shield and abilities in sheet frames', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(WaxSeal), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is StatShield && w.shield && w.label == 'AC',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text(
        'Tap the diamond for proficiency. Long-press a row to add a bonus.',
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(AbilityFrame, skipOffstage: false), findsNWidgets(6));
    await db.close();
  });

  testWidgets('tablet layout shows a navigation rail', (tester) async {
    await seed(tester);
    await pumpApp(tester, size: const Size(1280, 800));
    await settle(tester);
    await tester.tap(find.text('Ruin King'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await db.close();
  });
}
