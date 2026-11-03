import 'dart:math';

import 'package:engrammo/screens/benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
  });

  group('VerbalGamePage.wordPool', () {
    test('has no duplicates and no multi-word entries', () {
      for (final locale in ['en', 'hu']) {
        final pool = VerbalGamePage.wordPool(locale);
        expect(pool.toSet().length, pool.length, reason: locale);
        for (final w in pool) {
          expect(w.contains(' '), isFalse, reason: '$locale:$w');
          expect(w.trim().length, inInclusiveRange(2, 24));
        }
      }
    });

    test('covers the classic game words', () {
      expect(VerbalGamePage.wordPool('en'), contains('apple'));
      expect(VerbalGamePage.wordPool('hu'), contains('tükör'));
    });
  });

  group('VerbalGamePage.freshFallback', () {
    test('returns an unseen word even when the pool is exhausted', () {
      final pool = ['alma', 'körte'];
      final seen = {'alma', 'körte'};
      final w = VerbalGamePage.freshFallback(pool, seen, Random(1));
      expect(seen.contains(w), isFalse);
      expect(w.contains(' '), isFalse);
    });

    test('keeps producing unseen words over hundreds of rounds', () {
      final pool = ['alma', 'körte'];
      final seen = {'alma', 'körte'};
      final rnd = Random(7);
      for (var i = 0; i < 300; i++) {
        final w = VerbalGamePage.freshFallback(pool, seen, rnd);
        expect(seen.contains(w), isFalse, reason: 'round $i: $w');
        seen.add(w);
      }
    });

    test('does not hang on a single-word pool', () {
      final w = VerbalGamePage.freshFallback(
        ['alma'],
        {'alma'},
        Random(3),
      );
      expect(w, isNot('alma'));
      expect(w.contains(' '), isFalse);
    });
  });

  group('VerbalGamePage flow', () {
    String readWord(WidgetTester tester) {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.style?.fontSize == 40) return t.data ?? '';
      }
      throw StateError('verbal word not found');
    }

    testWidgets('fresh words keep coming after the pool is exhausted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VerbalGamePage()));
      await tester.pump();

      final seen = <String>{};
      var freshInTail = 0;
      const rounds = 250;
      for (var round = 0; round < rounds; round++) {
        final word = readWord(tester);
        expect(word, isNotEmpty);
        final saysSeen = seen.contains(word);
        seen.add(word);
        await tester.tap(find.text(saysSeen ? 'Seen' : 'New word'));
        await tester.pump();
        // The built-in pool is long exhausted by round 150: perfect play
        // must still meet genuinely new words, otherwise "Seen" spam
        // would score infinite points.
        if (round >= 150 && !saysSeen) freshInTail++;
      }
      expect(freshInTail, greaterThan(0));
    });
  });

  group('VerbalGamePage.takeAiWord', () {
    test('skips seen words case-insensitively', () {
      final queue = ['Apple', 'bridge', 'lamp'];
      expect(VerbalGamePage.takeAiWord(queue, {'apple'}), 'bridge');
      expect(queue, ['lamp']);
    });

    test('skips malformed entries and drains the queue', () {
      final queue = ['a', 'two words', 'xxxxxxxxxxxxxxxxxxxxxxxxxx', 'mirror'];
      expect(VerbalGamePage.takeAiWord(queue, <String>{}), 'mirror');
      expect(queue, isEmpty);
    });

    test('returns null when nothing new is left', () {
      expect(VerbalGamePage.takeAiWord([], <String>{}), isNull);
      expect(VerbalGamePage.takeAiWord(['seen'], {'Seen'}), isNull);
    });
  });

  group('LifeHeart', () {
    testWidgets('three filled hearts stay visible during play', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VerbalGamePage()));
      await tester.pump();
      final hearts = tester.widgetList<LifeHeart>(find.byType(LifeHeart));
      expect(hearts.length, 3);
      expect(hearts.every((h) => h.filled), isTrue);
      // Offline (no key in tests) the strip honestly says LOCAL: the
      // models join only when online.
      expect(find.textContaining('Local round'), findsOneWidget);
      expect(find.text('Local mode'), findsOneWidget);
      expect(find.textContaining('Muse Spark'), findsOneWidget);
    });

    testWidgets('a wrong guess empties exactly one heart', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VerbalGamePage()));
      await tester.pump();
      // The first word is always new, so SEEN is always wrong here.
      await tester.tap(find.text('Seen'));
      await tester.pump();
      final hearts = tester.widgetList<LifeHeart>(find.byType(LifeHeart));
      expect(hearts.length, 3);
      expect(hearts.where((h) => h.filled).length, 2);
    });

    testWidgets('game over shows the AI verdict with a question button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VerbalGamePage()));
      await tester.pump();
      String readWord() {
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          if (t.style?.fontSize == 40) return t.data ?? '';
        }
        throw StateError('verbal word not found');
      }

      final seen = <String>{};
      for (var i = 0; i < 3; i++) {
        final word = readWord();
        final saysSeen = seen.contains(word);
        seen.add(word);
        // Always answer wrong on purpose.
        await tester.tap(find.text(saysSeen ? 'New word' : 'Seen'));
        await tester.pump();
      }
      // The verdict arrives over async model calls (or their local
      // fallback chain) and sits below the fold of the result list:
      // wait for it and search the whole tree, like a scrolling user.
      final verdict = find.text('AI verdict', skipOffstage: false);
      for (var i = 0; i < 30; i++) {
        if (verdict.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(verdict, findsOneWidget);
      expect(
        find.text('Ask the AI coach', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('tap buttons answer without any voice button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VerbalGamePage()));
      await tester.pump();
      expect(find.text('Seen'), findsOneWidget);
      expect(find.text('New word'), findsOneWidget);
      expect(find.text('ANSWER BY VOICE'), findsNothing);
    });
  });
}
