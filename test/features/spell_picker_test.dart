import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';
import 'package:jjs_character_tracker/features/spells/spell_picker.dart';

import '../helpers/srd_catalog.dart';

class _Outcome {
  Spell? picked;
  bool closed = false;
}

void main() {
  setUpAll(loadTestSpellCatalog);

  Future<_Outcome> openPicker(
    WidgetTester tester, {
    double textScale = 1,
    List<String> classes = const [],
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final out = _Outcome();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  out.picked = await showModalBottomSheet<Spell>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => SpellPicker(classes: classes),
                  );
                  out.closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return out;
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.pumpAndSettle();
  }

  Future<void> chip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
  }

  testWidgets('opens with search, custom spell and first spells', (
    tester,
  ) async {
    await openPicker(tester);
    expect(find.text('Search spells'), findsOneWidget);
    expect(find.text('Create a custom spell'), findsOneWidget);
    expect(find.text('Acid Arrow'), findsOneWidget);
  });

  testWidgets('with nothing imported, hints to import and still allows custom', (
    tester,
  ) async {
    resetSpellCatalogForTests();
    addTearDown(loadTestSpellCatalog);
    await openPicker(tester);
    expect(find.textContaining('No spells imported yet'), findsOneWidget);
    expect(find.text('Create a custom spell'), findsOneWidget);
  });

  testWidgets('rows show level, school, casting time and range', (
    tester,
  ) async {
    await openPicker(tester);
    await search(tester, 'fireball');
    expect(
      find.text('Level 3 · Evocation · 1 action · 150 feet'),
      findsOneWidget,
    );
  });

  testWidgets('search narrows the list by name, ignoring case', (tester) async {
    await openPicker(tester);
    await search(tester, 'FIRE');
    expect(find.text('Fire Bolt'), findsOneWidget);
    expect(find.text('Fireball'), findsOneWidget);
    expect(find.text('Acid Arrow'), findsNothing);
  });

  testWidgets('the Cantrip chip keeps only cantrips', (tester) async {
    await openPicker(tester);
    await search(tester, 'fire');
    await chip(tester, 'Cantrip');
    expect(find.text('Fire Bolt'), findsOneWidget);
    expect(find.text('Fireball'), findsNothing);
  });

  testWidgets('a level chip combines with the search', (tester) async {
    await openPicker(tester);
    await chip(tester, '3');
    await search(tester, 'fireball');
    expect(find.text('Fireball'), findsOneWidget);
    expect(find.text('Fire Bolt'), findsNothing);
    await chip(tester, 'All');
    await search(tester, 'fire');
    expect(find.text('Fire Bolt'), findsOneWidget);
  });

  testWidgets('concentration and ritual show as icons on the row', (
    tester,
  ) async {
    await openPicker(tester);
    await search(tester, 'alarm');
    expect(find.byIcon(Icons.history_edu), findsOneWidget);
    expect(find.byIcon(Icons.psychology), findsNothing);
    await search(tester, 'haste');
    expect(find.byIcon(Icons.psychology), findsOneWidget);
  });

  testWidgets('a search with no matches says so', (tester) async {
    await openPicker(tester);
    await search(tester, 'zzzz');
    expect(find.text('No spells match'), findsOneWidget);
    expect(find.text('Create a custom spell'), findsOneWidget);
  });

  testWidgets('tapping a row opens the details; Add returns the spell', (
    tester,
  ) async {
    final out = await openPicker(tester);
    await search(tester, 'fireball');
    await tester.tap(find.text('Fireball'));
    await tester.pumpAndSettle();
    expect(out.closed, isFalse);
    expect(find.text('Add to character'), findsOneWidget);
    await tester.tap(find.text('Add to character'));
    await tester.pumpAndSettle();
    expect(out.closed, isTrue);
    expect(out.picked?.id, 'srd-fireball');
  });

  testWidgets('closing the details without Add keeps the picker open', (
    tester,
  ) async {
    final out = await openPicker(tester);
    await search(tester, 'fireball');
    await tester.tap(find.text('Fireball'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20)); // scrim above the details sheet
    await tester.pumpAndSettle();
    expect(out.closed, isFalse);
    expect(find.text('Create a custom spell'), findsOneWidget);
  });

  testWidgets('the custom spell option still creates a spell', (tester) async {
    // The test font (Ahem) is wider than real fonts; shrink it so the existing
    // dialog's dropdown rows do not overflow.
    final out = await openPicker(tester, textScale: 0.7);
    await tester.tap(find.text('Create a custom spell'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Zap');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(out.closed, isTrue);
    expect(out.picked?.name, 'Zap');
    expect(out.picked?.id, startsWith('spell'));
  });

  group('class restrictions', () {
    setUp(() {
      setSpellCatalog(const [
        Spell(id: 'any', name: 'Anyone Spell', level: 1),
        Spell(id: 'wiz', name: 'Wizard Spell', level: 1, classes: ['Wizard']),
        Spell(id: 'clr', name: 'Cleric Spell', level: 1, classes: ['Cleric']),
      ]);
    });
    tearDown(loadTestSpellCatalog);

    testWidgets('offers only spells open to the character class', (
      tester,
    ) async {
      await openPicker(tester, classes: ['Wizard']);
      expect(find.text('Anyone Spell'), findsOneWidget);
      expect(find.text('Wizard Spell'), findsOneWidget);
      expect(find.text('Cleric Spell'), findsNothing);
    });

    testWidgets('a multiclass character sees spells of either class', (
      tester,
    ) async {
      await openPicker(tester, classes: ['Wizard', 'Cleric']);
      expect(find.text('Wizard Spell'), findsOneWidget);
      expect(find.text('Cleric Spell'), findsOneWidget);
    });

    testWidgets('a new custom spell is pre-set to the character class', (
      tester,
    ) async {
      final out = await openPicker(tester, classes: ['Wizard']);
      await tester.tap(find.text('Create a custom spell'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'My Spell');
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      expect(out.picked?.classes, ['Wizard']);
    });
  });
}
