import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/features/spells/spell_picker.dart';

import '../helpers/srd_catalog.dart';

class _Outcome {
  Spell? picked;
  bool closed = false;
}

void main() {
  setUpAll(loadSrdCatalogForTests);

  Future<_Outcome> openPicker(
    WidgetTester tester, {
    double textScale = 1,
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
                    builder: (_) => const SpellPicker(),
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

  testWidgets('opens with search, custom spell, first spells and attribution', (
    tester,
  ) async {
    await openPicker(tester);
    expect(find.text('Search SRD spells'), findsOneWidget);
    expect(find.text('Create a custom spell'), findsOneWidget);
    expect(find.text('Acid Arrow'), findsOneWidget);
    expect(find.textContaining('SRD 5.1'), findsOneWidget);
    expect(find.textContaining('CC-BY-4.0'), findsOneWidget);
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
}
