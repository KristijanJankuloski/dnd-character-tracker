import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/theme.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('snack bar text is readable on its background', () {
    final t = buildTheme().snackBarTheme;
    expect(
      contrast(t.contentTextStyle!.color!, t.backgroundColor!),
      greaterThan(4.5),
    );
    expect(contrast(t.actionTextColor!, t.backgroundColor!), greaterThan(4.5));
    // The warning notice uses its own darker amber background.
    expect(
      contrast(t.contentTextStyle!.color!, const Color(0xFF4A3410)),
      greaterThan(4.5),
    );
  });

  testWidgets('snack bar content uses the light palette text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Hello'))),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    final style = DefaultTextStyle.of(tester.element(find.text('Hello'))).style;
    expect(style.color, Palette.text);
  });

  test('ink on parchment is readable', () {
    expect(contrast(Palette.ink, Palette.parchment), greaterThan(4.5));
  });
}
