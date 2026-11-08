import 'package:flutter/material.dart';

/// Dark fantasy palette taken from the mockup: near-black leather, crimson
/// banners, gold trim, parchment panels.
class Palette {
  static const bg = Color(0xFF120E0C);
  static const panel = Color(0xFF211914);
  static const panelHi = Color(0xFF2C2119);
  static const parchment = Color(0xFFE6D3A6);
  static const parchmentDark = Color(0xFFCDB683);
  static const ink = Color(0xFF2B1E12);
  static const gold = Color(0xFFC9A24B);
  static const goldDim = Color(0xFF8A6D2F);
  static const crimson = Color(0xFF7C1F1A);
  static const crimsonHi = Color(0xFFB02A22);
  static const text = Color(0xFFF1E3C3);
  static const textDim = Color(0xFFB9A582);
  static const arcane = Color(0xFF6C8EE0);
  static const violet = Color(0xFF9A5CD0);
  static const good = Color(0xFF6FA35A);
  static const warn = Color(0xFFE0A33A);
}

const String serif = 'serif';

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.gold,
    onPrimary: Palette.ink,
    secondary: Palette.crimsonHi,
    surface: Palette.panel,
    onSurface: Palette.text,
    error: Palette.crimsonHi,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    fontFamily: serif,
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: serif,
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.text,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Palette.panel,
      margin: EdgeInsets.zero,
    ),
    dividerColor: Palette.goldDim,
    dialogTheme: const DialogThemeData(backgroundColor: Palette.panel),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.panel,
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A130F),
      indicatorColor: Palette.crimson,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontFamily: serif, fontSize: 12, color: Palette.text),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF1A130F),
      indicatorColor: Palette.crimson,
      selectedLabelTextStyle: TextStyle(color: Palette.text, fontFamily: serif),
      unselectedLabelTextStyle: TextStyle(
        color: Palette.textDim,
        fontFamily: serif,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.text,
        minimumSize: const Size(48, 48),
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Palette.gold),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.gold,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Palette.goldDim),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Palette.goldDim),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Palette.goldDim),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Palette.gold, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.panelHi,
      side: const BorderSide(color: Palette.goldDim),
      labelStyle: const TextStyle(color: Palette.text, fontFamily: serif),
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
    ),
  );
}
