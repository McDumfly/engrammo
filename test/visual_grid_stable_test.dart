import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
    AppLocalizations.useCode(AppLocalizations.hungarianCode);
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  testWidgets('visual grid stays at the same Y across the text swap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VisualGamePage()));
    await tester.pump();
    expect(find.text('Jegyezd meg a mintát!'), findsOneWidget);

    // No auto-hide: waiting past the old 2200 ms delay must keep the
    // memorize screen, and only the got-it button flips the phase.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('Jegyezd meg a mintát!'), findsOneWidget);
    // Settle the scroll before measuring: the scroll itself moves the
    // grid, the text swap must not.
    await tester.ensureVisible(find.text('MEGVAN, KÉRDEZZ'));
    await tester.pump();
    final before = tester.getTopLeft(find.byType(GridView));
    await tester.tap(find.text('MEGVAN, KÉRDEZZ'));
    await tester.pump();
    expect(
      find.text('Koppints vissza ugyanazokra a mezőkre!'),
      findsOneWidget,
    );
    final after = tester.getTopLeft(find.byType(GridView));

    expect(after.dy, before.dy);
  });

  testWidgets('sequence grid stays at the same Y across the text swap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SequenceGamePage()));
    await tester.pump();
    final before = tester.getTopLeft(find.byType(GridView));

    // Level 1 plays one cell (600 + 550 + 250 ms), then the
    // instruction swaps to the turn text over the same grid.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      find.text('Te jössz! Ismételd meg a sorozatot.'),
      findsOneWidget,
    );
    final after = tester.getTopLeft(find.byType(GridView));

    expect(after.dy, before.dy);
  });
}
