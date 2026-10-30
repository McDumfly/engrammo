import 'package:engrammo/models/norms.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('z-scores and percentiles', () {
    test('literature priors exist with positive spread', () {
      expect(literatureNorms, isNotEmpty);
      for (final n in literatureNorms) {
        expect(n.sd, greaterThan(0));
        expect(n.source, isNotEmpty);
      }
      expect(priorFor('backward-span'), isNotNull);
      expect(priorFor('nope'), isNull);
    });

    test('normal CDF anchors: 0 -> 50%, +-1 -> ~84/16%', () {
      expect(normalCdf(0), closeTo(0.5, 1e-6));
      expect(percentileFromZ(0), closeTo(50, 1e-4));
      expect(percentileFromZ(1), closeTo(84.13, 0.05));
      expect(percentileFromZ(-1), closeTo(15.87, 0.05));
      expect(percentileFromZ(3), greaterThan(99));
    });

    test('bands split at 16/50/84', () {
      expect(bandForPercentile(90), contains('above'));
      expect(bandForPercentile(60), contains('around'));
      expect(bandForPercentile(30), contains('below'));
      expect(bandForPercentile(5), contains('well below'));
    });
  });

  group('reliability math', () {
    test('alpha is 1 for perfectly consistent items', () {
      final persons = [
        [1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0],
      ];
      expect(cronbachAlpha(persons), closeTo(1.0, 1e-9));
    });

    test('alpha is null when undefined', () {
      expect(cronbachAlpha([[1.0, 0.0]]), isNull);
      expect(
        cronbachAlpha([
          [1.0, 1.0],
          [1.0, 1.0],
          [1.0, 1.0],
        ]),
        isNull,
      );
    });

    test('split-half hits 1 for parallel halves', () {
      final persons = [
        [1.0, 1.0, 1.0, 1.0],
        [0.0, 0.0, 0.0, 0.0],
        [1.0, 1.0, 0.5, 0.5],
        [0.0, 0.0, 0.2, 0.2],
      ];
      expect(splitHalfReliability(persons), closeTo(1.0, 1e-9));
      expect(splitHalfReliability([[1.0, 0.0]]), isNull);
    });

    test('difficulties average, discriminations contrast thirds', () {
      final persons = [
        for (var i = 0; i < 6; i++)
          [1.0, i >= 3 ? 1.0 : 0.0],
      ];
      expect(itemDifficulties(persons), [1.0, closeTo(0.5, 1e-9)]);
      final disc = itemDiscriminations(persons);
      expect(disc[0], 0);
      expect(disc[1], closeTo(1.0, 1e-9));
    });
  });

  group('LocalNorm accumulator', () {
    test('tracks mean and sample sd (Welford)', () {
      final norm = LocalNorm();
      for (final x in [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]) {
        norm.add(x);
      }
      expect(norm.n, 8);
      expect(norm.mean, closeTo(5.0, 1e-9));
      expect(norm.sd, closeTo(2.138089935299395, 1e-9));
    });

    test('json round-trips', () {
      final norm = LocalNorm()
        ..add(0.5)
        ..add(1.0);
      final back = LocalNorm.fromJson(norm.toJson());
      expect(back.n, 2);
      expect(back.mean, closeTo(0.75, 1e-9));
      expect(back.sd, closeTo(norm.sd, 1e-9));
    });
  });

  group('MemoryStore norming sample', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('recorded runs feed norms and item rows', () async {
      final props = [for (var i = 0; i < 13; i++) i.isEven ? 1.0 : 0.5];
      await MemoryStore.recordAssessmentRun(
        itemProps: props,
        scores: [100, 60, 40, 80, 20, 0],
      );
      final norms = await MemoryStore.loadLocalNorms();
      expect(norms.length, 6);
      expect(norms[0]!.n, 1);
      expect(norms[0]!.mean, closeTo(1.0, 1e-9));
      expect(norms[5]!.mean, 0);
      final runs = await MemoryStore.loadAssessmentRunsData();
      expect(runs.length, 1);
      expect(runs.first.length, 13);
      expect(runs.first[1], closeTo(0.5, 1e-9));
    });

    test('empty store loads empty norms and runs', () async {
      expect(await MemoryStore.loadLocalNorms(), isEmpty);
      expect(await MemoryStore.loadAssessmentRunsData(), isEmpty);
    });
  });
}
