import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/ai_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Self-paced practice: memorize screens only ever hide through the
/// got-it button (no auto-hide timer), the memorize time is measured
/// and shown, a live clock ticks while playing, and the result shows
/// the total time. The palace walk shows no generated picture — the
/// player rehearses in their own palace.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  final spacedDigits = RegExp(r'^\d(  \d)+$');

  String readSpacedNumber(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere(spacedDigits.hasMatch);

  Future<void> tapGotIt(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> startPalaceWalk(
    WidgetTester tester, [
    String palace = 'My flat',
  ]) async {
    await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, palace);
    await tester.scrollUntilVisible(
      find.text('START WITH MY PALACE'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('START WITH MY PALACE'));
    await tester.pump();
    final gotIt = find.text('GOT IT, ASK ME');
    for (var i = 0; i < 30 && gotIt.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('No auto-advance in practice', () {
    testWidgets('number stays until the button, then shows the time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NumberGamePage()));
      await tester.pump();
      final number = readSpacedNumber(tester);
      expect(find.text('GOT IT, SHOW THE QUESTION'), findsOneWidget);
      expect(find.textContaining('Time:'), findsOneWidget);

      // Past the old 2500 ms auto-hide: still memorizing.
      await tester.pump(const Duration(seconds: 5));
      expect(readSpacedNumber(tester), number);
      expect(find.text('Which number did you see?'), findsNothing);

      await tapGotIt(tester, 'GOT IT, SHOW THE QUESTION');
      expect(find.text('Which number did you see?'), findsOneWidget);
      expect(find.textContaining('Memorized this one in'), findsOneWidget);

      // Correct answer: the next round is harder (4 digits).
      await tester.tap(find.text(number).first);
      await tester.pump();
      expect(find.text('4 digits'), findsOneWidget);

      // Wrong answer: the result shows the total time.
      final harder = readSpacedNumber(tester);
      await tapGotIt(tester, 'GOT IT, SHOW THE QUESTION');
      final options = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(spacedDigits.hasMatch)
          .toSet();
      expect(options.length, 4);
      final wrong = options.firstWhere((o) => o != harder);
      await tester.tap(find.text(wrong).first);
      await tester.pump();
      expect(find.text('3 digits!'), findsOneWidget);
      expect(find.textContaining('Total time:'), findsOneWidget);
    });

    testWidgets('palace walk stays until the button, then shows the time', (
      WidgetTester tester,
    ) async {
      await startPalaceWalk(tester);
      final pairs = RegExp(r'^\d+\. (.+) → (.+)$');
      int pairCount() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(pairs.hasMatch)
          .length;
      expect(pairCount(), 3);
      expect(find.text('GOT IT, ASK ME'), findsOneWidget);

      // Past the old 2500 + 3*900 ms auto-hide: still memorizing.
      await tester.pump(const Duration(seconds: 10));
      expect(pairCount(), 3);
      expect(
        find.textContaining(RegExp('^What did you place')),
        findsNothing,
      );

      await tapGotIt(tester, 'GOT IT, ASK ME');
      expect(
        find.textContaining(RegExp('^What did you place')),
        findsOneWidget,
      );
      expect(find.textContaining('Memorized this one in'), findsOneWidget);
      expect(find.textContaining('Time:'), findsOneWidget);
    });

    testWidgets('palace walk: no picture, no auto-hide, timed question', (
      WidgetTester tester,
    ) async {
      await startPalaceWalk(tester);
      final pairs = RegExp(r'^\d+\. (.+) → (.+)$');
      int pairCount() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(pairs.hasMatch)
          .length;
      expect(pairCount(), 3);
      // The player rehearses in their own palace: no generated picture.
      expect(find.byType(AiImage), findsNothing);

      // Past the old 2500 + 3*900 ms auto-hide: still memorizing.
      await tester.pump(const Duration(seconds: 6));
      expect(pairCount(), 3);
      expect(
        find.textContaining(RegExp('^What did you place')),
        findsNothing,
      );

      await tapGotIt(tester, 'GOT IT, ASK ME');
      expect(
        find.textContaining(RegExp('^What did you place')),
        findsOneWidget,
      );
      expect(find.textContaining('Memorized this one in'), findsOneWidget);
    });

    testWidgets('spatial setup speaks plain words, no loci jargon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.text('Your route stations, in order'), findsOneWidget);
      expect(find.text('Palace walk'), findsNothing);
      expect(find.text('My palace · list (practice)'), findsNothing);
      expect(
        find.textContaining(RegExp('loci', caseSensitive: false)),
        findsNothing,
      );
    });
  });
}
