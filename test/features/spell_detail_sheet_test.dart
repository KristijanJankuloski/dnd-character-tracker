import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';
import 'package:jjs_character_tracker/features/spells/spell_detail_sheet.dart';

import '../helpers/srd_catalog.dart';

class _Outcome {
  bool? result;
  bool closed = false;
}

void main() {
  setUpAll(loadSrdCatalogForTests);

  Spell spellNamed(String n) => srdSpells.firstWhere((s) => s.name == n);

  Future<_Outcome> openSheet(
    WidgetTester tester,
    Spell spell, {
    required bool canAdd,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final out = _Outcome();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  out.result = await showSpellDetailSheet(
                    ctx,
                    spell,
                    canAdd: canAdd,
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

  group('spellCastingLabel', () {
    test('uses the written casting time, cut at the first comma', () {
      expect(spellCastingLabel(spellNamed('Shield')), '1 reaction');
      expect(spellCastingLabel(spellNamed('Alarm')), '1 minute');
    });

    test('falls back to the enum for spells without the text', () {
      const old = Spell(id: 'x', name: 'Old', level: 1);
      expect(spellCastingLabel(old), 'Action');
      expect(
        spellCastingLabel(
          const Spell(
            id: 'y',
            name: 'Quick',
            level: 1,
            castingTime: CastingTime.bonusAction,
          ),
        ),
        'Bonus Action',
      );
    });
  });

  group('showSpellDetailSheet', () {
    testWidgets('shows every detail of an encyclopedia spell', (tester) async {
      await openSheet(tester, spellNamed('Fireball'), canAdd: false);
      expect(find.text('Fireball'), findsOneWidget);
      expect(find.textContaining('Level 3'), findsOneWidget);
      expect(find.textContaining('Evocation'), findsOneWidget);
      expect(find.text('Casting time'), findsOneWidget);
      expect(find.text('1 action'), findsOneWidget);
      expect(find.text('Range'), findsOneWidget);
      expect(find.text('150 feet'), findsOneWidget);
      expect(find.text('Components'), findsOneWidget);
      expect(
        find.text('V, S, M (a tiny ball of bat guano and sulfur)'),
        findsOneWidget,
      );
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Instantaneous'), findsOneWidget);
      expect(find.text('8d6 fire'), findsOneWidget);
      expect(find.text('Radius / sphere (20 ft)'), findsOneWidget);
      expect(find.text('Dexterity'), findsOneWidget);
      expect(find.textContaining('A bright streak flashes'), findsOneWidget);
      expect(find.text('At Higher Levels'), findsOneWidget);
      expect(
        find.textContaining('increases by 1d6 for each slot level above 3rd'),
        findsOneWidget,
      );
    });

    testWidgets('shows the full casting time of a reaction spell', (tester) async {
      await openSheet(tester, spellNamed('Shield'), canAdd: false);
      expect(find.textContaining('1 reaction, which you take when'), findsOneWidget);
    });

    testWidgets('Add to character completes with true', (tester) async {
      final out = await openSheet(tester, spellNamed('Fireball'), canAdd: true);
      await tester.tap(find.text('Add to character'));
      await tester.pumpAndSettle();
      expect(out.closed, isTrue);
      expect(out.result, isTrue);
    });

    testWidgets('no Add button when the spell is already known', (tester) async {
      await openSheet(tester, spellNamed('Fireball'), canAdd: false);
      expect(find.text('Add to character'), findsNothing);
    });

    testWidgets('an old-style spell shows no blank rows', (tester) async {
      await openSheet(
        tester,
        const Spell(id: 'x', name: 'Old', level: 1, range: '30 ft'),
        canAdd: true,
      );
      expect(find.text('Casting time'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('30 ft'), findsOneWidget);
      expect(find.text('Components'), findsNothing);
      expect(find.text('Duration'), findsNothing);
      expect(find.text('At Higher Levels'), findsNothing);
      expect(find.text('Damage'), findsNothing);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('dismissing the sheet completes with null', (tester) async {
      final out = await openSheet(tester, spellNamed('Fireball'), canAdd: true);
      await tester.tapAt(const Offset(200, 20)); // the scrim above the sheet
      await tester.pumpAndSettle();
      expect(out.closed, isTrue);
      expect(out.result, isNull);
    });
  });
}
