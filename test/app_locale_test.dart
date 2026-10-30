import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/main.dart';
import 'package:engrammo/services/app_settings.dart';
import 'package:engrammo/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectivityService.testOverride = true;
  });

  tearDown(() async {
    connectivityService.resetForTest();
    await appSettings.setLanguage(AppLocalizations.englishCode);
  });

  testWidgets('Hungarian locale resolves Material localizations', (
    tester,
  ) async {
    await appSettings.setLanguage(AppLocalizations.hungarianCode);
    await tester.pumpWidget(const MyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('hu'));
    expect(
      app.localizationsDelegates,
      contains(GlobalMaterialLocalizations.delegate),
    );
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(const Locale('hu')),
      isTrue,
    );

    final element = tester.element(find.byType(Scaffold).first);
    expect(MaterialLocalizations.of(element).backButtonTooltip, 'Vissza');
  });

  testWidgets('English locale still resolves Material localizations', (
    tester,
  ) async {
    await appSettings.setLanguage(AppLocalizations.englishCode);
    await tester.pumpWidget(const MyApp());

    final element = tester.element(find.byType(Scaffold).first);
    expect(MaterialLocalizations.of(element).backButtonTooltip, 'Back');
  });
}
