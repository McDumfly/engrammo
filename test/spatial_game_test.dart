import 'dart:math';

import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('SpatialGamePage helpers', () {
    test('pickStations returns the requested distinct stations', () {
      final stations = SpatialGamePage.pickStations(4, routeIndex: 0);
      expect(stations.length, 4);
      expect(stations.toSet().length, 4);
    });

    test('pickStations clamps to 3..10', () {
      expect(SpatialGamePage.pickStations(1, routeIndex: 0).length, 3);
      expect(SpatialGamePage.pickStations(99, routeIndex: 0).length, 10);
    });

    test('pickWords returns distinct nouns', () {
      final words = SpatialGamePage.pickWords(5, Random(42));
      expect(words.length, 5);
      expect(words.toSet().length, 5);
    });

    test('makeOptions holds the answer plus 3 fresh lures', () {
      final options = SpatialGamePage.makeOptions(
        'apple',
        ['apple', 'hammer'],
        Random(7),
      );
      expect(options.length, 4);
      expect(options, contains('apple'));
      expect(options.toSet().length, 4);
      expect(options, isNot(contains('hammer')));
    });

    test('localWonderPreview captions every station in order', () {
      final views = SpatialGamePage.localWonderPreview(['door', 'hall']);
      expect(views.length, 2);
      expect(views[0], contains('door'));
      expect(views[1], contains('hall'));
    });
  });

  group('SpatialGamePage flow', () {
    Map<String, String> readPairs(WidgetTester tester) {
      final out = <String, String>{};
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final d = t.data ?? '';
        if (d.contains(' → ')) {
          final parts = d.split(' → ');
          out[parts[0]] = parts[1];
        }
      }
      return out;
    }

    String readTarget(WidgetTester tester) {
      const prefix = 'What did you place at the ';
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final d = t.data ?? '';
        if (d.startsWith(prefix) && d.endsWith('?')) {
          return d.substring(prefix.length, d.length - 1);
        }
      }
      throw StateError('spatial question not found');
    }

    List<String> readOptions(WidgetTester tester) {
      final out = <String>[];
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final d = t.data ?? '';
        if (d.isNotEmpty && !d.contains(' ') && !d.contains('?')) {
          out.add(d);
        }
      }
      return out;
    }

    testWidgets('hub lists the spatial memory card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: BenchmarkHubPage()));
      await tester.pump();
      expect(find.text('Spatial memory'), findsOneWidget);
      expect(find.text('Walk the palace route!'), findsOneWidget);
    });

    testWidgets('correct answer advances to more stations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      final pairs = readPairs(tester);
      expect(pairs.length, 3);

      await tester.ensureVisible(find.text('GOT IT, ASK ME'));
      await tester.pump();
      await tester.tap(find.text('GOT IT, ASK ME'));
      await tester.pump();

      final target = readTarget(tester);
      final correct = pairs[target]!;
      expect(readOptions(tester), contains(correct));

      await tester.tap(find.text(correct));
      await tester.pump();

      expect(find.text('4 stations'), findsOneWidget);
      expect(readPairs(tester).length, 4);
    });

    testWidgets('wrong answer ends the run with a restart', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      final pairs = readPairs(tester);

      await tester.ensureVisible(find.text('GOT IT, ASK ME'));
      await tester.pump();
      await tester.tap(find.text('GOT IT, ASK ME'));
      await tester.pump();

      final target = readTarget(tester);
      final correct = pairs[target]!;
      final wrong = readOptions(
        tester,
      ).firstWhere((o) => o != correct);

      await tester.tap(find.text(wrong));
      await tester.pump();

      expect(find.text('RESTART'), findsOneWidget);

      await tester.tap(find.text('RESTART'));
      await tester.pump();
      expect(find.text('3 stations'), findsOneWidget);
      expect(readPairs(tester).length, 3);
    });

    testWidgets('memorize phase offers the camera palace', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.text('USE MY ROOM (CAMERA + SAM)'), findsOneWidget);
    });

    testWidgets('memorize phase shows the wonder preview', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Wonder route preview'), findsOneWidget);
      // Offline the local captions still cover every station.
      expect(find.textContaining('Look toward the'), findsNWidgets(3));
    });

    testWidgets('camera failure degrades to one inline line', (
      WidgetTester tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'camera_unavailable'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      // The camera room needs cloud AI (key + consent); with both set, a
      // throwing picker lands on the 'unavailable' line.
      await MetaAIService.setStoredApiKey('test-key');
      MetaAIService.consentForTest = true;
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.ensureVisible(
        find.text('USE MY ROOM (CAMERA + SAM)'),
      );
      await tester.pump();
      await tester.tap(find.text('USE MY ROOM (CAMERA + SAM)'));
      await tester.pump();
      // The camera error travels over async platform channels and the
      // inline line lands below the scrolled button: wait for it and
      // search the whole tree.
      final camErr = find.textContaining(
        'Camera is unavailable',
        skipOffstage: false,
      );
      for (var i = 0; i < 30; i++) {
        if (camErr.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(camErr, findsOneWidget);
      // The palace route is untouched: the pairs are still there.
      expect(readPairs(tester).length, 3);
    });

    testWidgets('cancelled camera stays silent on the palace route', (
      WidgetTester tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      await tester.ensureVisible(
        find.text('USE MY ROOM (CAMERA + SAM)'),
      );
      await tester.pump();
      await tester.tap(find.text('USE MY ROOM (CAMERA + SAM)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Camera is unavailable'), findsNothing);
      expect(find.text('USE MY ROOM (CAMERA + SAM)'), findsOneWidget);
      expect(readPairs(tester).length, 3);
    });

    testWidgets('game over shows the AI verdict with a question button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      final pairs = readPairs(tester);
      await tester.ensureVisible(find.text('GOT IT, ASK ME'));
      await tester.pump();
      await tester.tap(find.text('GOT IT, ASK ME'));
      await tester.pump();
      final target = readTarget(tester);
      final correct = pairs[target]!;
      final wrong = readOptions(tester).firstWhere((o) => o != correct);
      await tester.tap(find.text(wrong));
      await tester.pump();
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
        find.text('ASK THE AI COACH', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
