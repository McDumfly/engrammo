import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart'
    show
        blue,
        blueDark,
        coral,
        coralDark,
        ink,
        line,
        muted,
        orange,
        orangeDark,
        success,
        teal,
        tealDark;
import 'app_tokens.dart';

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
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
          primary: blue,
          secondary: teal,
          tertiary: orange,
          surface: darkScaffold,
        ).copyWith(
          onSurface: darkOnSurface,
          onSurfaceVariant: darkOnSurfaceVariant,
          surfaceContainerHigh: darkCard,
          surfaceContainerHighest: darkInput,
          outlineVariant: darkBorder,
          surfaceTint: Colors.transparent,
          primaryContainer: darkCard,
          secondaryContainer: darkInput,
          surfaceContainer: darkCard,
          surfaceContainerLow: darkCard,
          surfaceContainerLowest: darkCard,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: blue,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: darkScaffold,
      cardColor: darkCard,
      canvasColor: darkScaffold,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: blue,
        selectionColor: blue.withValues(alpha: 0.25),
        selectionHandleColor: blue,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(0),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: TextTheme(
        displaySmall: AppText.display.copyWith(color: darkOnSurface),
        headlineSmall: AppText.title.copyWith(color: darkOnSurface),
        titleLarge: AppText.title.copyWith(color: darkOnSurface),
        titleMedium: AppText.heading.copyWith(color: darkOnSurface),
        bodyLarge: AppText.body.copyWith(color: darkOnSurface),
        bodyMedium: AppText.body.copyWith(color: darkOnSurface),
        bodySmall: AppText.caption.copyWith(color: darkOnSurface),
        labelSmall: AppText.micro.copyWith(color: darkOnSurface),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        foregroundColor: darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      tabBarTheme: const TabBarThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
    );
  }

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
          primary: blue,
          secondary: teal,
          tertiary: orange,
          surface: Colors.white,
        ).copyWith(
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerHigh: Colors.white,
          surfaceContainerHighest: const Color(0xFFF4F8FE),
          outlineVariant: line,
          surfaceTint: Colors.transparent,
          primaryContainer: Colors.white,
          secondaryContainer: const Color(0xFFF4F8FE),
          surfaceContainer: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainerLowest: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: blue,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF6F9FD),
      cardColor: Colors.white,
      canvasColor: const Color(0xFFF6F9FD),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: blue,
        selectionColor: blue.withValues(alpha: 0.25),
        selectionHandleColor: blue,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(0),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: TextTheme(
        displaySmall: AppText.display.copyWith(color: ink),
        headlineSmall: AppText.title.copyWith(color: ink),
        titleLarge: AppText.title.copyWith(color: ink),
        titleMedium: AppText.heading.copyWith(color: ink),
        bodyLarge: AppText.body.copyWith(color: ink),
        bodyMedium: AppText.body.copyWith(color: ink),
        bodySmall: AppText.caption.copyWith(color: ink),
        labelSmall: AppText.micro.copyWith(color: ink),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      tabBarTheme: const TabBarThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
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

  /// Accessible text colour: bright brand fills stay bright in dark mode,
  /// but map to their dark variants on light backgrounds.
  Color accentText(Color c) {
    if (isDark) return c;
    if (c == teal) return tealDark;
    if (c == orange) return orangeDark;
    if (c == coral) return coralDark;
    if (c == blue) return blueDark;
    if (c == success) return success;
    return c;
  }
}
