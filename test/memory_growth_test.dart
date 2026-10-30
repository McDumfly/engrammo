import 'package:engrammo/models/assessment.dart' show levelForScores;
import 'package:engrammo/models/battle_match.dart'
    show BattleOutcome, battleGrowthBase;
import 'package:engrammo/models/curriculum.dart'
    show memoryTracks, trackChapters, trackOfChapter;
import 'package:engrammo/screens/lesson_player.dart' show lessonSessionStars;
import 'package:engrammo/services/memory_growth.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('growth diminishing returns', () {
    test('delta table: full at 0, half at 50, +1 near cap, 0 at 100', () {
      expect(growthDelta(score: 0, base: 3), 3);
      expect(growthDelta(score: 50, base: 2), 1);
      expect(growthDelta(score: 50, base: 3), 2);
      expect(growthDelta(score: 90, base: 3), 1);
      expect(growthDelta(score: 99, base: 3), 1);
      expect(growthDelta(score: 100, base: 3), 0);
    });

    test('delta clamps base and score, never negative or over room', () {
      expect(growthDelta(score: 0, base: 9), 3);
      expect(growthDelta(score: 0, base: 0), 0);
      expect(growthDelta(score: 0, base: -2), 0);
      expect(growthDelta(score: 150, base: 3), 0);
      expect(growthDelta(score: 99, base: 3), 1); // room is 1
    });

    test('applyPracticeGain is pure, capped, kind-safe', () {
      final scores = [10, 20, 99, 100, 0, 50];
      final next = applyPracticeGain(scores, 0, 3);
      expect(scores, [10, 20, 99, 100, 0, 50]); // input untouched
      expect(next[0], 10 + growthDelta(score: 10, base: 3));
      expect(next.sublist(1), [20, 99, 100, 0, 50]);

      expect(applyPracticeGain(scores, 2, 3)[2], 100); // ceiling
      expect(applyPracticeGain(scores, 3, 3)[3], 100); // maxed stays
      expect(applyPracticeGain(scores, -1, 3), scores); // invalid kind
      expect(applyPracticeGain(scores, 6, 3), scores);
    });
  });

  group('growth daily cap', () {
    final day1 = DateTime(2026, 10, 28, 12);
    final day2 = DateTime(2026, 10, 29, 12);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MemoryStore.onChanged = null;
    });

    tearDown(() {
      MemoryStore.onChanged = null;
    });

    Future<void> seed(List<int> scores) =>
        MemoryStore.saveScoresWithoutNotify(scores);

    test('+5 per kind per day, then blocked', () async {
      await seed([10, 10, 10, 10, 10, 10]);
      await applyGrowth(kind: 0, base: 3, now: day1); // +3 -> 13
      await applyGrowth(kind: 0, base: 3, now: day1); // +2 -> 15 (cap)
      final after = await applyGrowth(kind: 0, base: 3, now: day1);
      expect(after![0], 15);
      expect(after.sublist(1), [10, 10, 10, 10, 10]);
    });

    test('cap is per kind and resets next day', () async {
      await seed([10, 10, 10, 10, 10, 10]);
      for (var i = 0; i < 4; i++) {
        await applyGrowth(kind: 0, base: 3, now: day1);
      }
      // Kind 1 still has its own full budget.
      final other = await applyGrowth(kind: 1, base: 3, now: day1);
      expect(other![1], 10 + growthDelta(score: 10, base: 3));
      // Next day the kind-0 budget is fresh again.
      final nextDay = await applyGrowth(kind: 0, base: 3, now: day2);
      expect(nextDay![0], greaterThan(other[0]));
    });

    test('growth never touches the assessment-runs counter', () async {
      await seed([10, 10, 10, 10, 10, 10]);
      final before = await MemoryStore.loadAssessmentRuns();
      await applyGrowth(kind: 0, base: 3, now: day1);
      expect(await MemoryStore.loadAssessmentRuns(), before);
    });

    test('no assessment yet yields null; bad input is a no-op', () async {
      expect(await applyGrowth(kind: 0, base: 3, now: day1), isNull);
      await seed([10, 10, 10, 10, 10, 10]);
      expect(
        await applyGrowth(kind: 9, base: 3, now: day1),
        [10, 10, 10, 10, 10, 10],
      );
      expect(
        await applyGrowth(kind: 0, base: 0, now: day1),
        [10, 10, 10, 10, 10, 10],
      );
    });

    test('growth notifies listeners', () async {
      await seed([10, 10, 10, 10, 10, 10]);
      var notified = false;
      MemoryStore.onChanged = () async => notified = true;
      await applyGrowth(kind: 0, base: 3, now: day1);
      for (var i = 0; i < 10 && !notified; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(notified, isTrue);
    });
  });

  group('growth level mapping', () {
    test('levelForScores matches the explainer formula', () {
      expect(levelForScores(const []), 1);
      expect(levelForScores(const [0, 0, 0, 0, 0, 0]), 1);
      expect(levelForScores(const [9, 9, 9, 9, 9, 9]), 1);
      expect(levelForScores(const [10, 10, 10, 10, 10, 10]), 2);
      expect(levelForScores(const [55, 61, 74, 86, 68, 48]), 7);
      expect(levelForScores(const [100, 100, 100, 100, 100, 100]), 11);
    });

    test('one practice gain can lift the level across a boundary', () {
      final scores = [9, 10, 10, 10, 10, 10];
      expect(levelForScores(scores), 1);
      final grown = applyPracticeGain(scores, 0, 3);
      expect(levelForScores(grown), 2);
    });
  });

  group('growth hook mapping', () {
    test('battle base: win up to 3, draw up to 1, loss 0', () {
      expect(
        battleGrowthBase(outcome: BattleOutcome.win, exact: 3, rounds: 3),
        3,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.win, exact: 2, rounds: 3),
        2,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.win, exact: 1, rounds: 3),
        1,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.win, exact: 0, rounds: 3),
        0,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.draw, exact: 3, rounds: 3),
        1,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.draw, exact: 1, rounds: 3),
        0,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.loss, exact: 3, rounds: 3),
        0,
      );
      expect(
        battleGrowthBase(outcome: BattleOutcome.win, exact: 0, rounds: 0),
        0,
      );
    });

    test('lesson stars feed the growth base as 1..3', () {
      const fast = Duration(seconds: 5);
      const slow = Duration(minutes: 5);
      expect(
        lessonSessionStars(correct: 3, total: 3, elapsed: fast),
        3,
      );
      expect(
        lessonSessionStars(correct: 3, total: 3, elapsed: slow),
        2,
      );
      expect(lessonSessionStars(correct: 2, total: 4, elapsed: fast), 2);
      expect(lessonSessionStars(correct: 1, total: 4, elapsed: fast), 1);
      expect(lessonSessionStars(correct: 0, total: 0, elapsed: fast), 1);
    });

    test('every lesson chapter maps to its track kind', () {
      for (var track = 0; track < trackChapters.length; track++) {
        for (final chapter in trackChapters[track]) {
          expect(
            trackOfChapter(chapter),
            track,
            reason: 'chapter $chapter',
          );
        }
      }
      for (var chapter = 0; chapter < 40; chapter++) {
        expect(
          trackOfChapter(chapter),
          inInclusiveRange(0, memoryTracks.length - 1),
        );
      }
      expect(trackOfChapter(-1), 0);
      expect(trackOfChapter(9999), 0);
    });
  });
}
