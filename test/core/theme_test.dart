import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/frames.dart';
import 'package:jjs_character_tracker/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the two typefaces are bundled with the app', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final families = {for (final f in manifest) (f as Map)['family']};
    expect(families, containsAll(<String>[serif, display]));
  });

  test('reading text uses the book face, titles the inscription face', () {
    final t = buildTheme();
    expect(serif, 'Alegreya');
    expect(display, 'Cinzel');
    expect(t.textTheme.bodyMedium!.fontFamily, serif);
    expect(t.textTheme.labelLarge!.fontFamily, serif);
    expect(t.textTheme.titleLarge!.fontFamily, display);
    expect(t.appBarTheme.titleTextStyle!.fontFamily, display);
    expect(t.dialogTheme.titleTextStyle!.fontFamily, display);
  });

  group('digits inside inscription text', () {
    // The inscription face draws 1 like a capital I, so "Level 11" would read
    // as "Level II". Its digits are removed from the bundled file and the
    // book face supplies them instead.
    double width(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return p.width;
    }

    const book = TextStyle(
      fontFamily: serif,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      fontFeatures: liningFigures,
    );

    test('are drawn by the book face in panel titles and captions', () {
      final style = displayStyle(size: 40, spacing: 0);
      for (final digit in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(width(digit, style), width(digit, book), reason: digit);
      }
    });

    test('are drawn by the book face in app bar and dialog titles', () {
      final t = buildTheme();
      for (final themed in [
        t.textTheme.titleLarge!,
        t.appBarTheme.titleTextStyle!,
        t.dialogTheme.titleTextStyle!,
      ]) {
        final style = themed.copyWith(fontSize: 40, letterSpacing: 0);
        expect(width('11', style), width('11', book));
      }
    });

    test('letters still use the inscription face', () {
      final style = displayStyle(size: 40, spacing: 0);
      expect(width('Level', style), isNot(width('Level', book)));
    });
  });

  test('every text style uses lining figures so 1 never reads as I', () {
    final t = buildTheme().textTheme;
    for (final s in [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
    ]) {
      expect(s!.fontFeatures, contains(const FontFeature.liningFigures()));
    }
  });

  test('buttons, chips, dialogs and sheets share the cut-corner shape', () {
    final t = buildTheme();
    final outlined = t.outlinedButtonTheme.style!.shape!.resolve({});
    final filled = t.filledButtonTheme.style!.shape!.resolve({});
    expect(outlined, isA<BeveledRectangleBorder>());
    expect(filled, isA<BeveledRectangleBorder>());
    expect(t.chipTheme.shape, isA<BeveledRectangleBorder>());
    expect(t.dialogTheme.shape, isA<BeveledRectangleBorder>());
    expect(t.bottomSheetTheme.shape, isA<BeveledRectangleBorder>());
    expect(t.navigationBarTheme.indicatorShape, isA<BeveledRectangleBorder>());
    expect(t.inputDecorationTheme.border, isA<CutCornerInputBorder>());
  });
}
