import 'package:engrammo/models/assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreForPair', () {
    test('easy 40 + hard 60', () {
      expect(scoreForPair(easyCorrect: true, hardCorrect: true), 100);
      expect(scoreForPair(easyCorrect: true, hardCorrect: false), 40);
      expect(scoreForPair(easyCorrect: false, hardCorrect: true), 60);
      expect(scoreForPair(easyCorrect: false, hardCorrect: false), 0);
    });
  });

  group('dominantKind', () {
    test('null = never assessed', () {
      expect(dominantKind(null), isNull);
      expect(dominantKind([]), isNull);
    });

    test('highest wins, ties go to lowest index', () {
      expect(dominantKind([40, 100, 60, 0, 40, 100]), 1);
      expect(dominantKind([100, 100, 100, 100, 100, 100]), 0);
    });
  });

  group('resolveDominant (tie ladder)', () {
    test('null or blank scores crown nobody', () {
      expect(resolveDominant(scores: null).kind, isNull);
      expect(resolveDominant(scores: const []).kind, isNull);
      expect(
        resolveDominant(scores: const [0, 0, 0, 0, 0, 0]).kind,
        isNull,
      );
    });

    test('clear winner needs no tie-break', () {
      final r = resolveDominant(scores: const [40, 100, 60, 0, 40, 60]);
      expect(r.kind, 1);
      expect(r.tied, [1]);
    });

    test('hard items break the tie (they discriminate, easy ones ceiling)', () {
      final r = resolveDominant(
        scores: const [100, 100, 60, 0, 0, 0],
        hardHits: const [1, 0, 1, 0, 0, 0],
      );
      expect(r.kind, 0);
      expect(r.rationale, contains('hard'));
    });

    test('faster recall breaks a remaining tie', () {
      final r = resolveDominant(
        scores: const [100, 100, 0, 0, 0, 0],
        hardHits: const [1, 1, 0, 0, 0, 0],
        latenciesMs: const [1800, 900, 0, 0, 0, 0],
      );
      expect(r.kind, 1);
      expect(r.rationale, contains('fast'));
    });

    test('interview verdict picks among the tied top only', () {
      final r = resolveDominant(
        scores: const [100, 100, 100, 100, 100, 100],
        interviewKind: 4,
      );
      expect(r.kind, 4);
      // ...but never overrides a clear performance gap:
      final r2 = resolveDominant(
        scores: const [100, 100, 60, 0, 0, 0],
        interviewKind: 2,
      );
      expect(r2.kind, isNull);
      expect(r2.tied, [0, 1]);
    });

    test('unbreakable tie stays balanced, never a fake winner', () {
      final r = resolveDominant(
        scores: const [100, 100, 100, 100, 100, 100],
      );
      expect(r.kind, isNull);
      expect(r.tied.length, 6);
      expect(r.rationale, contains('alanced'));
    });
  });

  group('assessmentColorChips', () {
    test('names are unique and match the rendered hue', () {
      final names = assessmentColorChips.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
      for (final chip in assessmentColorChips) {
        final r = (chip.argb >> 16) & 0xFF;
        final g = (chip.argb >> 8) & 0xFF;
        final b = chip.argb & 0xFF;
        switch (chip.name) {
          case 'Blue':
            expect(b, greaterThan(r));
          case 'Green':
            expect(g, greaterThan(r));
          case 'Orange':
            expect(r, greaterThan(b));
          case 'Red':
            expect(r, greaterThan(g));
          case 'Purple':
            expect(b, greaterThan(g));
          case 'Yellow':
            expect(r, greaterThan(b));
            expect(g, greaterThan(b));
          default:
            fail('unexpected chip ${chip.name}');
        }
      }
    });

    test('chipNotAmong returns a chip that was really absent', () {
      final shown = assessmentColorChips.take(3).toList();
      final missing = chipNotAmong(shown);
      expect(shown.map((c) => c.name), isNot(contains(missing.name)));
    });
  });

  group('scoresAreBlank', () {
    test('null, empty and all-zero are blank', () {
      expect(scoresAreBlank(null), isTrue);
      expect(scoresAreBlank([]), isTrue);
      expect(scoresAreBlank([0, 0, 0, 0, 0, 0]), isTrue);
      expect(scoresAreBlank([0, 40, 0, 0, 0, 0]), isFalse);
    });
  });

  group('levelForScores', () {
    test('empty starts at level 1', () {
      expect(levelForScores([]), 1);
    });

    test('matches the profile formula (avg ~/ 10 + 1)', () {
      expect(levelForScores([55, 61, 74, 86, 68, 48]), 7);
      expect(levelForScores([0, 0, 0, 0, 0, 0]), 1);
      expect(levelForScores([100, 100, 100, 100, 100, 100]), 11);
    });
  });

  group('starsForLesson', () {
    test('fast correct = 3, slow correct = 2, wrong = 1', () {
      expect(
        starsForLesson(correct: true, elapsed: const Duration(seconds: 5)),
        3,
      );
      expect(
        starsForLesson(correct: true, elapsed: const Duration(seconds: 30)),
        2,
      );
      expect(
        starsForLesson(correct: false, elapsed: const Duration(seconds: 5)),
        1,
      );
    });
  });
}
