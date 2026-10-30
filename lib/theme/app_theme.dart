import 'package:flutter/material.dart';

import 'app_colors.dart' show blueDark, coral, coralDark, ink, line, muted, blue;

class AppTheme {
  static const OutlinedBorder buttonShape = StadiumBorder();

  static const String fontFamily = 'Lexend';

  static const darkScaffold = Color(0xFF101A2C);
  static const darkCard = Color(0xFF1B2740);
  static const darkInput = Color(0xFF24334D);
  static const darkWash = Color(0xFF1A2C46);
  static const darkFaint = Color(0xFF141E31);
  static const darkBorder = Color(0xFF2C3B55);
  static const darkOnSurface = Color(0xFFEAF1FB);
  static const darkOnSurfaceVariant = Color(0xFF9DACC4);

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
          primary: blue,
          secondary: const Color(0xFF14B8A6),
          tertiary: const Color(0xFFFF9500),
          surface: darkScaffold,
        ).copyWith(
          onSurface: darkOnSurface,
          onSurfaceVariant: darkOnSurfaceVariant,
          surfaceContainerHigh: darkCard,
          surfaceContainerHighest: darkInput,
          outlineVariant: darkBorder,
        );

    const heavy = TextStyle(fontWeight: FontWeight.w900, fontSize: 15);
    const firm = TextStyle(fontWeight: FontWeight.w800, fontSize: 14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: blue,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: darkScaffold,
      cardColor: darkCard,
      canvasColor: darkScaffold,
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1.5),
      dialogTheme: const DialogThemeData(backgroundColor: darkCard),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: const TextStyle(color: darkOnSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder, width: 1.5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        hintStyle: const TextStyle(
          color: darkOnSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        foregroundColor: darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: darkCard),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blueDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: buttonShape,
          textStyle: heavy,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blueDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: buttonShape,
          textStyle: heavy,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkOnSurface,
          side: const BorderSide(color: Color(0xFF2C3B55), width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: buttonShape,
          textStyle: firm,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: firm,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkOnSurface,
          overlayColor: Colors.transparent,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: const SwitchThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
    );
  }

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          primary: blue,
          secondary: const Color(0xFF14B8A6),
          tertiary: const Color(0xFFFF9500),
          surface: Colors.white,
        ).copyWith(
          onSurface: ink,
          onSurfaceVariant: muted,
        );

    const heavy = TextStyle(fontWeight: FontWeight.w900, fontSize: 15);
    const firm = TextStyle(fontWeight: FontWeight.w800, fontSize: 14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: blue,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: Colors.white,
      dividerTheme: const DividerThemeData(color: line, thickness: 1.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F8FE),
        hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blueDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: buttonShape,
          textStyle: heavy,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blueDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: buttonShape,
          textStyle: heavy,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: muted,
          side: const BorderSide(color: line, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: buttonShape,
          textStyle: firm,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blueDark,
          textStyle: firm,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          overlayColor: Colors.transparent,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: const SwitchThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
    );
  }
}

extension ThemeCtx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardBg => isDark ? AppTheme.darkCard : Colors.white;

  Color get softBg => isDark ? AppTheme.darkInput : const Color(0xFFF4F8FE);

  Color get washBg => isDark ? AppTheme.darkWash : const Color(0xFFEFF6FF);

  Color get faintBg => isDark ? AppTheme.darkFaint : const Color(0xFFF1F5FA);

  Color get hairline => isDark ? AppTheme.darkBorder : const Color(0xFFDEE9F7);

  Color get washBorder =>
      isDark ? AppTheme.darkBorder : const Color(0xFFD2E6FC);

  Color get faintBorder =>
      isDark ? AppTheme.darkBorder : const Color(0xFFE3EDF8);

  Color get inkText => Theme.of(this).colorScheme.onSurface;

  Color get mutedText => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get dangerText => isDark ? coral : coralDark;
}
