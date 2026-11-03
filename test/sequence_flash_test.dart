import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/theme/app_colors.dart';
import 'package:engrammo/widgets/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A1: the learner's own taps flash (tick for correct, coral for wrong)
/// and the result box only appears after the 650 ms reveal delay.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  Finder tiles() => find.descendant(
    of: find.byType(GridView),
    matching: find.byType(Tappable),
  );

  Finder tileBoxes() => find.descendant(
    of: find.byType(GridView),
    matching: find.byType(AnimatedContainer),
  );

  /// Plays level 1 until the turn starts and returns the index of the
  /// first sequence cell (observed while it lights up during the demo).
  /// Uses a tall surface so every tile is hittable without scrolling.
  Future<int> reachTurn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SequenceGamePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    var lit = -1;
    for (var i = 0; i < 9; i++) {
      final box =
          tester.widget<AnimatedContainer>(tileBoxes().at(i)).decoration
              as BoxDecoration;
      if (box.color == orange) lit = i;
    }
    expect(lit, isNot(-1));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Your turn! Repeat the sequence.'), findsOneWidget);
    return lit;
  }

  Finder icon(List<List<dynamic>> icon) =>
      find.byWidgetPredicate((w) => w is HugeIcon && w.icon == icon);

  testWidgets('correct first tap shows the tick, gone after 200 ms', (
    WidgetTester tester,
  ) async {
    final first = await reachTurn(tester);
    await tester.tap(tiles().at(first));
    await tester.pump();
    expect(icon(HugeIcons.strokeRoundedTick02), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(icon(HugeIcons.strokeRoundedTick02), findsNothing);
    // Flush the delayed next-round playback so no timer is left pending.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('wrong tap delays the result box past 650 ms', (
    WidgetTester tester,
  ) async {
    final first = await reachTurn(tester);
    final wrong = (first + 1) % 9;
    await tester.tap(tiles().at(wrong));
    await tester.pump();
    expect(icon(HugeIcons.strokeRoundedCancel01), findsOneWidget);
    // Still hidden before the 650 ms reveal (checked twice under 650 ms).
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nice streak!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Nice streak!'), findsNothing);
    // The reveal fires at +650 ms; poll past it with slack for harness
    // scroll-settle jitter, then require the result box.
    var shown = false;
    for (var i = 0; i < 15 && !shown; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      shown = find.text('Nice streak!').evaluate().isNotEmpty;
    }
    expect(shown, isTrue);
  });
}
