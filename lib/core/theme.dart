import 'package:flutter/material.dart';

import 'frames.dart';

/// Dark fantasy palette taken from the mockup: near-black leather, crimson
/// banners, gold trim, parchment panels.
class Palette {
  static const bg = Color(0xFF120E0C);
  static const panel = Color(0xFF211914);
  static const panelHi = Color(0xFF2C2119);
  static const parchment = Color(0xFFE6D3A6);
  static const parchmentDark = Color(0xFFCDB683);

  /// Lighter parchment for frames drawn on a parchment panel.
  static const parchmentHi = Color(0xFFF3E6C4);
  static const ink = Color(0xFF2B1E12);

  /// Secondary ink for hints and captions on parchment.
  static const inkDim = Color(0xFF5A4630);

  /// Heading red on parchment, as in a printed stat block.
  static const inkRed = Color(0xFF7A1A14);
  static const gold = Color(0xFFC9A24B);
  static const goldDim = Color(0xFF8A6D2F);
  static const crimson = Color(0xFF7C1F1A);
  static const crimsonHi = Color(0xFFB02A22);
  static const text = Color(0xFFF1E3C3);
  static const textDim = Color(0xFFB9A582);
  static const arcane = Color(0xFF6C8EE0);

  /// [arcane] darkened to stay readable on parchment.
  static const arcaneInk = Color(0xFF2F4A9A);
  static const violet = Color(0xFF9A5CD0);
  static const good = Color(0xFF6FA35A);
  static const warn = Color(0xFFE0A33A);

  /// Tab bar and rail background.
  static const bar = Color(0xFF1A130F);

  // Top-to-bottom fills for the drawn frames.
  static const panelTop = Color(0xFF281D17);
  static const panelBottom = Color(0xFF1D1511);
  static const plateTop = Color(0xFF35271D);
  static const plateBottom = Color(0xFF271C15);

  /// The faint second line set just inside a gold frame.
  static const goldHairline = Color(0x52C9A24B);
}

/// Book face for reading text and every number.
const String serif = 'Alegreya';

/// Inscription face for names, titles and captions. Its lowercase letters are
/// small capitals, so strings keep their normal casing.
///
/// The original draws 1 like a capital I, so "Level 11" would read "Level II".
/// The bundled file has its digits removed (see assets/fonts/README.md) and
/// every style that uses it names [serif] as the fallback, so digits inside a
/// title are drawn by the book face. Always go through [displayStyle].
const String display = 'Cinzel';

/// Alegreya defaults to old-style figures; the sheet wants the lining ones.
const List<FontFeature> liningFigures = [FontFeature.liningFigures()];

/// A [display] style for titles and captions.
TextStyle displayStyle({
  required double size,
  Color? color,
  double spacing = 1,
}) => TextStyle(
  fontFamily: display,
  fontFamilyFallback: const [serif],
  fontSize: size,
  fontWeight: FontWeight.w700,
  fontFeatures: liningFigures,
  letterSpacing: spacing,
  color: color,
  height: 1.2,
);

/// A [serif] style for big sheet numbers.
TextStyle numberStyle({required double size, Color? color}) => TextStyle(
  fontFamily: serif,
  fontSize: size,
  fontWeight: FontWeight.w800,
  fontFeatures: liningFigures,
  color: color,
  height: 1.1,
);

const _cut = BeveledRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

BeveledRectangleBorder _framed(double cut, {double width = 1}) =>
    BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(cut)),
      side: BorderSide(color: Palette.goldDim, width: width),
    );

TextTheme _textTheme() {
  final base = ThemeData.dark().textTheme.apply(
    fontFamily: serif,
    bodyColor: Palette.text,
    displayColor: Palette.text,
  );
  TextStyle body(TextStyle? s, [double? size]) => s!.copyWith(
    fontFamily: serif,
    fontSize: size,
    letterSpacing: 0,
    fontFeatures: liningFigures,
  );
  TextStyle title(TextStyle? s, double size) => s!.copyWith(
    fontFamily: display,
    fontFamilyFallback: const [serif],
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: .6,
    fontFeatures: liningFigures,
  );
  return base.copyWith(
    displayLarge: body(base.displayLarge),
    displayMedium: body(base.displayMedium),
    displaySmall: body(base.displaySmall),
    headlineLarge: body(base.headlineLarge),
    headlineMedium: body(base.headlineMedium),
    headlineSmall: body(base.headlineSmall),
    titleLarge: title(base.titleLarge, 19),
    // List tile titles and text field input.
    titleMedium: body(base.titleMedium, 17),
    titleSmall: body(base.titleSmall, 15.5),
    bodyLarge: body(base.bodyLarge, 17),
    bodyMedium: body(base.bodyMedium, 15.5),
    bodySmall: body(base.bodySmall, 13.5),
    // Buttons and chips.
    labelLarge: body(
      base.labelLarge,
      15.5,
    ).copyWith(fontWeight: FontWeight.w700),
    labelMedium: body(base.labelMedium, 13.5),
    labelSmall: body(base.labelSmall, 12.5),
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.gold,
    onPrimary: Palette.ink,
    secondary: Palette.crimsonHi,
    onSecondary: Palette.text,
    secondaryContainer: Palette.plateTop,
    onSecondaryContainer: Palette.gold,
    tertiary: Palette.arcane,
    surface: Palette.panel,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.textDim,
    surfaceContainerLowest: Palette.bg,
    surfaceContainerLow: Palette.panel,
    surfaceContainer: Palette.panel,
    surfaceContainerHigh: Palette.panelHi,
    surfaceContainerHighest: Palette.panelHi,
    surfaceTint: Colors.transparent,
    outline: Palette.goldDim,
    outlineVariant: Color(0xFF4D3D1E),
    error: Palette.crimsonHi,
  );
  final text = _textTheme();
  final button = text.labelLarge!;
  final caption = displayStyle(size: 10.5, spacing: 1.1);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    fontFamily: serif,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: Palette.panel,
      margin: EdgeInsets.zero,
      shape: _framed(10, width: 1.5),
    ),
    dividerColor: Palette.goldDim,
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.panel,
      shape: _framed(12, width: 1.5),
      titleTextStyle: text.titleLarge!.copyWith(
        fontSize: 18,
        color: Palette.gold,
      ),
      contentTextStyle: text.bodyMedium,
    ),
    // Material 3 snack bars default to inverseSurface/onInverseSurface, which
    // this dark scheme leaves as light-on-dark-text; keep them on the palette.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.panelHi,
      contentTextStyle: text.bodyMedium!.copyWith(color: Palette.text),
      actionTextColor: Palette.gold,
      closeIconColor: Palette.text,
      shape: _framed(6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Palette.panel,
      showDragHandle: true,
      dragHandleColor: Palette.goldDim,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: Palette.goldDim, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.bar,
      height: 72,
      indicatorColor: Palette.crimson,
      indicatorShape: _cut.copyWith(
        side: const BorderSide(color: Palette.gold),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 23,
          color: s.contains(WidgetState.selected)
              ? Palette.text
              : Palette.textDim,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => caption.copyWith(
          color: s.contains(WidgetState.selected)
              ? Palette.text
              : Palette.textDim,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Palette.bar,
      indicatorColor: Palette.crimson,
      indicatorShape: _cut.copyWith(
        side: const BorderSide(color: Palette.gold),
      ),
      selectedIconTheme: const IconThemeData(color: Palette.text),
      unselectedIconTheme: const IconThemeData(color: Palette.textDim),
      selectedLabelTextStyle: caption.copyWith(color: Palette.text),
      unselectedLabelTextStyle: caption.copyWith(color: Palette.textDim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.text,
        minimumSize: const Size(48, 48),
        textStyle: button,
        shape: _cut.copyWith(side: const BorderSide(color: Palette.gold)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.gold,
        backgroundColor: const Color(0x0DC9A24B),
        minimumSize: const Size(48, 48),
        textStyle: button,
        side: const BorderSide(color: Palette.goldDim),
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.gold,
        textStyle: button,
        shape: _cut,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Palette.crimson,
      foregroundColor: Palette.text,
      extendedTextStyle: button,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: Palette.gold, width: 1.5),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: CutCornerInputBorder(
        borderSide: BorderSide(color: Palette.goldDim),
      ),
      enabledBorder: CutCornerInputBorder(
        borderSide: BorderSide(color: Palette.goldDim),
      ),
      focusedBorder: CutCornerInputBorder(
        borderSide: BorderSide(color: Palette.gold, width: 2),
      ),
      errorBorder: CutCornerInputBorder(
        borderSide: BorderSide(color: Palette.crimsonHi),
      ),
      focusedErrorBorder: CutCornerInputBorder(
        borderSide: BorderSide(color: Palette.crimsonHi, width: 2),
      ),
      labelStyle: TextStyle(color: Palette.textDim),
      floatingLabelStyle: TextStyle(color: Palette.gold),
      hintStyle: TextStyle(color: Palette.textDim),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.panelHi,
      selectedColor: Palette.crimson,
      checkmarkColor: Palette.gold,
      side: const BorderSide(color: Palette.goldDim),
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      labelStyle: text.bodyMedium!.copyWith(color: Palette.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Palette.gold : Palette.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.crimson
            : Palette.panelHi,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Palette.goldDim),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.gold : null,
      ),
      checkColor: const WidgetStatePropertyAll(Palette.ink),
      side: const BorderSide(color: Palette.goldDim, width: 1.5),
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.gold,
      linearTrackColor: Palette.panelHi,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.panelHi,
      shape: _framed(8),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: ShapeDecoration(color: Palette.panelHi, shape: _framed(5)),
      textStyle: text.bodySmall!.copyWith(color: Palette.text),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.gold,
      selectionColor: Color(0x66C9A24B),
      selectionHandleColor: Palette.gold,
    ),
  );
}
