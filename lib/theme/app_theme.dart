import 'package:flutter/material.dart';

import 'app_colors.dart' show ink, line, muted, blue;

/// Az app egyetlen közös témája.
///
/// - Szín: minden gomb az app kékjét (blue) használja alapként.
/// - Betű: egyetlen betűtípus fut végig az appban, a Lexend
///   (helyi asset, `assets/fonts/`). Olvashatóságra és tanulásra
///   tervezett, barátságos, mégis modern és komoly betű, magyar
///   ékezetekkel. Direkt nincs sehol egyedi `fontFamily`,
///   hogy ne csússzon szét a tipográfia — a családot csak ez a
///   téma adja meg, minden felirat örökli.
///
/// Sötét módban minden felület sötét: a kártyák, beviteli mezők,
/// ikon-dobozok és elválasztók a lenti sötét palettából jönnek, nem
/// marad fehér folt. A képernyők a [ThemeCtx] kiterjesztésen
/// (`context.cardBg`, `context.inkText` stb.) keresztül kérdezik le
/// a színeket, így világos módban pontosan a régi külső marad.
class AppTheme {
  /// Döntés (2026-10, végleges: pill + lapos): minden gomb
  /// teljesen lekerekített pill (Stadium) és direkt lapos —
  /// nincs 3D-s alsó sáv.
  ///
  /// A vastag alsó árnyéksáv idegen márkajegy lenne, ezért direkt
  /// nem használjuk sehol. Ezért minden gombtípus [buttonShape] formát
  /// kap világos és sötét módban is, és ezentúl mindig ez az
  /// alapértelmezett: új gombhoz nem kell `shape`-et írni.
  /// A lapos készletet az `app_buttons.dart` adja ([EngramButton]
  /// nagy CTA, [EngramMiniButton] kis inline akció,
  /// [EngramIconButton]/[EngramBackButton] ikon-only kör) —
  /// új kódban mindig ezeket használd. Az ikon-only kör tudatos
  /// kivétel (1:1-es pill, egyetlen ikon oválisban szétcsúszna),
  /// ezért a memóriatípus-választó is kör marad. Más kivétel
  /// nincs: TextButton szöveges link marad, de minden nyomható
  /// gomb (dialógus-actions, FloatingActionButton is) pill.
  /// Nem gomb (kártya, badge,
  /// input, játéktábla-cella, progress-sáv) nem tartozik ide.
  static const OutlinedBorder buttonShape = StadiumBorder();

  /// Az app betűcsaládja (pubspec `fonts`: Lexend, változó 100–900).
  static const String fontFamily = 'Lexend';

  /// Sötét téma: sötétkék háttér, világos feliratok, sötét kártyák.
  ///
  /// Minden, ami világos módban fehér vagy halványkék felület
  /// (kártya, input-mező, kijelölt sor, zárolt sor, elválasztó),
  /// sötét módban ennek a palettának a megfelelő tagját kapja.
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
      // Az appban sehol nincs koppintási hullám (splash/ripple).
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
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
          backgroundColor: blue,
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
        backgroundColor: blue,
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
          // A háttéren ülő címsorok ezeket használják, így világos
          // módban pontosan a régi színeket kapják.
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
      // Az appban sehol nincs koppintási hullám (splash/ripple):
      // minden érintés azonnali, fény- és hullámeffekt nélkül.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
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
          backgroundColor: blue,
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
          foregroundColor: blue,
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
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
    );
  }
}

/// Témakövető felületszínek: minden képernyő ezeken keresztül kéri le
/// a háttereket, szövegeket és elválasztókat, így sötét módban semmi
/// nem marad fehérre égetve, világos módban pedig a régi külső marad.
///
/// - [cardBg]: kártyák, lapok, dialógusok háttere.
/// - [softBg]: beviteli mezők és ikondobozok kitöltése.
/// - [washBg]: kijelölt/aktív halványkék sávok.
/// - [faintBg]: zárolt/inaktív halvány sávok, csík-háttér.
/// - [hairline]: 2px-es keretek, elválasztók.
/// - [inkText]/[mutedText]: elsődleges/másodlagos feliratok.
extension ThemeCtx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardBg => isDark ? AppTheme.darkCard : Colors.white;

  Color get softBg => isDark ? AppTheme.darkInput : const Color(0xFFF4F8FE);

  Color get washBg => isDark ? AppTheme.darkWash : const Color(0xFFEFF6FF);

  Color get faintBg => isDark ? AppTheme.darkFaint : const Color(0xFFF1F5FA);

  Color get hairline => isDark ? AppTheme.darkBorder : const Color(0xFFDEE9F7);

  /// Világos módban a régi halványkék keretek, sötétben a sötét keret.
  Color get washBorder =>
      isDark ? AppTheme.darkBorder : const Color(0xFFD2E6FC);

  Color get faintBorder =>
      isDark ? AppTheme.darkBorder : const Color(0xFFE3EDF8);

  Color get inkText => Theme.of(this).colorScheme.onSurface;

  Color get mutedText => Theme.of(this).colorScheme.onSurfaceVariant;
}
