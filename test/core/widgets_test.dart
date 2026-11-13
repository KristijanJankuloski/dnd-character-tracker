import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/frames.dart';
import 'package:jjs_character_tracker/core/theme.dart';
import 'package:jjs_character_tracker/core/widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Finder painted<T extends CustomPainter>() =>
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T);

  group('AbilityFrame', () {
    testWidgets('shows the abbreviation, modifier and score', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 110,
          child: AbilityFrame(abbr: 'STR', modifier: '-1', score: '8'),
        ),
      );
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(painted<AbilityFramePainter>(), findsOneWidget);
    });

    testWidgets('reads as one button and reports taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        SizedBox(
          width: 110,
          child: AbilityFrame(
            abbr: 'CHA',
            modifier: '+4',
            score: '18',
            semanticsLabel: 'Charisma +4, score 18',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Charisma +4, score 18'));
      expect(taps, 1);
    });

    testWidgets('marks a score that modifiers have changed', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 110,
          child: AbilityFrame(abbr: 'CON', modifier: '+2', score: '14'),
        ),
      );
      expect(find.byType(ChangedMark), findsNothing);
      await pump(
        tester,
        const SizedBox(
          width: 110,
          child: AbilityFrame(
            abbr: 'CON',
            modifier: '+3',
            score: '16',
            changed: true,
          ),
        ),
      );
      expect(find.byType(ChangedMark), findsOneWidget);
    });
  });

  group('StatShield', () {
    testWidgets('draws a real shield when asked to', (tester) async {
      await pump(
        tester,
        const StatShield(label: 'AC', value: '15', shield: true),
      );
      expect(painted<ShieldPainter>(), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('draws an engraved plate otherwise', (tester) async {
      await pump(tester, const StatShield(label: 'Speed', value: '30 ft'));
      expect(painted<ShieldPainter>(), findsNothing);
      expect(painted<CutFramePainter>(), findsOneWidget);
    });
  });

  group('Panel', () {
    testWidgets('dark panels get a cut frame and a gold inscription title', (
      tester,
    ) async {
      await pump(tester, const Panel(title: 'Conditions', child: Text('x')));
      expect(painted<CutFramePainter>(), findsOneWidget);
      final title = tester.widget<Text>(find.text('Conditions'));
      expect(title.style!.fontFamily, display);
      expect(title.style!.color, Palette.gold);
    });

    testWidgets('parchment panels get a scroll plate and a red title', (
      tester,
    ) async {
      await pump(
        tester,
        const Panel(title: 'Skills', parchment: true, child: Text('x')),
      );
      expect(painted<ParchmentPainter>(), findsOneWidget);
      final title = tester.widget<Text>(find.text('Skills'));
      expect(title.style!.fontFamily, display);
      expect(title.style!.color, Palette.inkRed);
      final body = DefaultTextStyle.of(tester.element(find.text('x'))).style;
      expect(body.color, Palette.ink);
    });
  });

  testWidgets('outline and text buttons on parchment are inked, not gold', (
    tester,
  ) async {
    await pump(
      tester,
      Panel(
        parchment: true,
        child: Row(
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('Off-hand')),
            TextButton(onPressed: () {}, child: const Text('More')),
          ],
        ),
      ),
    );
    for (final label in ['Off-hand', 'More']) {
      final style = DefaultTextStyle.of(tester.element(find.text(label))).style;
      expect(style.color, Palette.inkRed, reason: label);
    }
  });

  testWidgets('buttons on dark panels stay gold', (tester) async {
    await pump(
      tester,
      Panel(
        child: OutlinedButton(onPressed: () {}, child: const Text('Go')),
      ),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('Go'))).style;
    expect(style.color, Palette.gold);
  });

  testWidgets('Pips: a filled pip spends, an empty pip restores', (
    tester,
  ) async {
    var spent = 0, restored = 0;
    await pump(
      tester,
      Pips(
        total: 3,
        filled: 1,
        onSpend: () => spent++,
        onRestore: () => restored++,
      ),
    );
    final pips = find.byType(InkResponse);
    expect(pips, findsNWidgets(3));
    await tester.tap(pips.at(0));
    await tester.tap(pips.at(2));
    expect((spent, restored), (1, 1));
  });

  testWidgets('WaxSeal shows the initials on a painted seal', (tester) async {
    await pump(tester, const WaxSeal(initials: 'TV'));
    expect(find.text('TV'), findsOneWidget);
    expect(painted<SealPainter>(), findsOneWidget);
  });

  testWidgets('ProficiencyMark names its level for screen readers', (
    tester,
  ) async {
    await pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProficiencyMark(ProficiencyLevel.none),
          ProficiencyMark(ProficiencyLevel.proficient),
          ProficiencyMark(ProficiencyLevel.expertise),
        ],
      ),
    );
    expect(find.bySemanticsLabel('Not proficient'), findsOneWidget);
    expect(find.bySemanticsLabel('Proficient'), findsOneWidget);
    expect(find.bySemanticsLabel('Expertise'), findsOneWidget);
  });
}
