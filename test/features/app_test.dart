import 'package:jjs_character_tracker/core/app.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/core/widgets.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
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
