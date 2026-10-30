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

    test('is the 0/1 endpoint of the single partial-credit rule', () {
      for (final easy in [false, true]) {
        for (final hard in [false, true]) {
          expect(
            scoreForPair(easyCorrect: easy, hardCorrect: hard),
            pointsForProportion(proportion: easy ? 1 : 0, hard: false) +
                pointsForProportion(proportion: hard ? 1 : 0, hard: true),
          );
        }
      }
    });
  });

  group('pointsForProportion', () {
    test('splits the same 40/60 budget by partial credit', () {
      expect(pointsForProportion(proportion: 1, hard: false), 40);
      expect(pointsForProportion(proportion: 1, hard: true), 60);
      expect(pointsForProportion(proportion: 0.5, hard: false), 20);
      expect(pointsForProportion(proportion: 0.75, hard: true), 45);
      expect(pointsForProportion(proportion: 0, hard: true), 0);
    });

    test('clamps outside 0..1', () {
      expect(pointsForProportion(proportion: 2, hard: true), 60);
      expect(pointsForProportion(proportion: -1, hard: false), 0);
    });
  });

  group('pointsForBudget', () {
    test('splits any probe budget by partial credit', () {
      expect(pointsForBudget(proportion: 1, max: 50), 50);
      expect(pointsForBudget(proportion: 0.5, max: 30), 15);
      expect(pointsForBudget(proportion: 0, max: 20), 0);
    });

    test('spatial budgets sum to the same 100 as the pairs', () {
      expect(
        spatialProbeBudgets.reduce((a, b) => a + b),
        100,
      );
      expect(assessmentProbeCount, 13);
    });
  });

  group('corsiProbeSequences', () {
    test('3 levels x 4 forms: lengths 3/5/6, distinct cells 0-8', () {
      expect(corsiProbeSequences.length, 3);
      const lengths = [3, 5, 6];
      for (var level = 0; level < 3; level++) {
        expect(corsiProbeSequences[level].length, 4);
        for (final seq in corsiProbeSequences[level]) {
          expect(seq.length, lengths[level]);
          expect(seq.toSet().length, seq.length);
          for (final cell in seq) {
            expect(cell, inInclusiveRange(0, 8));
          }
        }
      }
    });

    test('no level contains another level as a run within a form', () {
      bool containsRun(List<int> hay, List<int> needle) {
        if (needle.length > hay.length) return false;
        outer:
        for (var i = 0; i + needle.length <= hay.length; i++) {
          for (var j = 0; j < needle.length; j++) {
            if (hay[i + j] != needle[j]) continue outer;
          }
          return true;
        }
        return false;
      }

      for (var form = 0; form < 4; form++) {
        final easy = corsiProbeSequences[0][form];
        final medium = corsiProbeSequences[1][form];
        final hard = corsiProbeSequences[2][form];
        expect(
          containsRun(medium, easy),
          isFalse,
          reason: 'form $form medium must not contain easy',
        );
        expect(
          containsRun(hard, easy),
          isFalse,
          reason: 'form $form hard must not contain easy',
        );
        expect(
          containsRun(hard, medium),
          isFalse,
          reason: 'form $form hard must not contain medium',
        );
      }
    });
  });

  group('blind span direction', () {
    test('every form has a defined direction', () {
      expect(backEasyReversedByForm.length, 4);
      expect(backHardReversedByForm.length, 4);
    });

    test('easy reveals nothing about hard (no pre-reverse cheat)', () {
      var hardRevGivenEasyRev = 0;
      var easyRevCount = 0;
      var hardRevGivenEasyFwd = 0;
      var easyFwdCount = 0;
      for (var form = 0; form < 4; form++) {
        if (backEasyReversed(form)) {
          easyRevCount++;
          if (backHardReversed(form)) hardRevGivenEasyRev++;
        } else {
          easyFwdCount++;
          if (backHardReversed(form)) hardRevGivenEasyFwd++;
        }
      }
      expect(easyRevCount, 2);
      expect(easyFwdCount, 2);
      expect(hardRevGivenEasyRev / easyRevCount, 0.5);
      expect(hardRevGivenEasyFwd / easyFwdCount, 0.5);
    });
  });

  group('sensory cues', () {
    test('easy cues one valid slot of 3, varying by form', () {
      expect(iconicEasyCueByForm.length, 4);
      for (final cue in iconicEasyCueByForm) {
        expect(cue, inInclusiveRange(0, 2));
      }
      expect(iconicEasyCueByForm.toSet().length, greaterThan(1));
    });

    test('hard cues two distinct valid slots of 6, varying by form', () {
      expect(iconicHardCuesByForm.length, 4);
      for (final cues in iconicHardCuesByForm) {
        expect(cues.length, 2);
        expect(cues[0], isNot(cues[1]));
        for (final cue in cues) {
          expect(cue, inInclusiveRange(0, 5));
        }
      }
      final patterns = {
        for (final cues in iconicHardCuesByForm) cues.join(','),
      };
      expect(patterns.length, 4);
    });
  });

  group('ordinal', () {
    test('1st/2nd/3rd/4th and teens', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
      expect(ordinal(5), '5th');
      expect(ordinal(6), '6th');
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
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
