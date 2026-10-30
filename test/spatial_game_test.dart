import 'dart:math';

import 'package:engrammo/screens/benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}
