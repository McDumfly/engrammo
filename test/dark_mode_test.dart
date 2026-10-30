import 'package:engrammo/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dark mode palette', () {
    test('Sötét témában minden felület sötét', () {
      final dark = AppTheme.dark();
      expect(dark.brightness, Brightness.dark);
      expect(dark.cardColor, AppTheme.darkCard);
      expect(dark.scaffoldBackgroundColor, AppTheme.darkScaffold);
      expect(
        ThemeData.estimateBrightnessForColor(AppTheme.darkCard),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(AppTheme.darkInput),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(AppTheme.darkWash),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(AppTheme.darkFaint),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(AppTheme.darkBorder),
        Brightness.dark,
      );
    });

    test('Világos téma felületei változatlanok', () {
      final light = AppTheme.light();
      expect(light.brightness, Brightness.light);
      expect(light.cardColor, Colors.white);
      expect(light.scaffoldBackgroundColor, Colors.white);
    });

    testWidgets('A ThemeCtx sötét módban sötét felületeket ad', (tester) async {
      Color? darkCard;
      Color? darkHairline;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              darkCard = context.cardBg;
              darkHairline = context.hairline;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(darkCard, AppTheme.darkCard);
      expect(darkHairline, AppTheme.darkBorder);
      expect(ThemeData.estimateBrightnessForColor(darkCard!), Brightness.dark);
      expect(
        ThemeData.estimateBrightnessForColor(darkHairline!),
        Brightness.dark,
      );
    });

    testWidgets('A ThemeCtx világos módban a régi fehér felületeket adja', (
      tester,
    ) async {
      Color? lightCard;
      Color? lightHairline;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              lightCard = context.cardBg;
              lightHairline = context.hairline;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(lightCard, Colors.white);
      expect(lightHairline, const Color(0xFFDEE9F7));
    });
  });
}
