import 'package:engrammo/models/assessment.dart';
import 'package:engrammo/models/battle_rating.dart';
import 'package:engrammo/models/collectibles.dart';
import 'package:engrammo/models/memory_verdict.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/screens/battle_zone.dart' show memoryLevelForScore;
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/utils/streak_restore.dart';
import 'package:engrammo/utils/streak_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('stars max-merge', () {
    test('replay never downgrades stars', () async {
      await MemoryStore.saveLessonStars(
        chapter: 1,
        section: 0,
        lesson: 0,
        stars: 3,
      );
      await MemoryStore.saveLessonStars(
        chapter: 1,
        section: 0,
        lesson: 0,
        stars: 1,
      );
      final p = await MemoryStore.loadChapterProgress();
      expect(p[MemoryStore.lessonKey(1, 0, 0)], 3);
    });

    test('replay can still upgrade stars', () async {
      await MemoryStore.saveLessonStars(
        chapter: 1,
        section: 0,
        lesson: 1,
        stars: 1,
      );
      await MemoryStore.saveLessonStars(
        chapter: 1,
        section: 0,
        lesson: 1,
        stars: 3,
      );
      final p = await MemoryStore.loadChapterProgress();
      expect(p[MemoryStore.lessonKey(1, 0, 1)], 3);
    });
  });

  group('level clamp', () {
    test('memoryLevelForScore clamps to 1..11', () {
      expect(memoryLevelForScore(0), 1);
      expect(memoryLevelForScore(100), 11);
      expect(memoryLevelForScore(150), 11);
      expect(memoryLevelForScore(-5), 1);
    });

    test('memoryLevelForScore matches levelForScores bands', () {
      for (final s in [0, 9, 10, 55, 99, 100]) {
        expect(memoryLevelForScore(s), levelForScores([s]));
      }
    });
  });

  group('chipNotAmong', () {
    test('returns a chip outside the shown set', () {
      final shown = assessmentColorChips.sublist(0, 3);
      final missing = chipNotAmong(shown);
      expect(shown.map((c) => c.name), isNot(contains(missing.name)));
    });

    test('never throws when the palette is covered', () {
      final missing = chipNotAmong(assessmentColorChips);
      expect(
        assessmentColorChips.map((c) => c.name),
        contains(missing.name),
      );
    });
  });

  group('heuristicVerdict blank guard', () {
    test('blank input claims no winner', () {
      final v = heuristicVerdict(
        scores: const [0, 0, 0, 0, 0, 0],
        answers: const [],
      );
      expect(v.fallback, isTrue);
      expect(v.confidence, 0.5);
      expect(v.rationale, contains('Nothing measurable'));
    });

    test('hard hits break exact ties', () {
      final v = heuristicVerdict(
        scores: const [60, 60, 60, 60, 60, 60],
        answers: const [],
        hardHits: const [0, 0, 2, 0, 0, 0],
      );
      expect(v.kind, 2);
    });
  });

  group('parseTaskContent rejects bad correct', () {
    const req = MetaTaskRequest(kind: 'working', difficulty: 2);

    test('out-of-range correct falls back to local', () {
      final high = MetaAIService.parseTaskContent(
        '{"prompt":"P","items":["3","7","1"],"question":"Q?",'
        '"options":["a","b","c","d"],"correct":9}',
        req,
      );
      final neg = MetaAIService.parseTaskContent(
        '{"prompt":"P","items":["3","7","1"],"question":"Q?",'
        '"options":["a","b","c","d"],"correct":-1}',
        req,
      );
      expect(high, isNull);
      expect(neg, isNull);
    });

    test('missing correct falls back to local', () {
      final missing = MetaAIService.parseTaskContent(
        '{"prompt":"P","items":["3","7","1"],"question":"Q?",'
        '"options":["a","b","c","d"]}',
        req,
      );
      expect(missing, isNull);
    });

    test('in-range correct still parses', () {
      final task = MetaAIService.parseTaskContent(
        '{"prompt":"P","items":["3","7","1"],"question":"Q?",'
        '"options":["a","b","c","d"],"correct":2}',
        req,
      );
      expect(task, isNotNull);
      expect(task!.correct, 2);
      expect(task.fallback, isFalse);
    });
  });

  group('streak calendar math', () {
    test('dayDiff is DST-safe', () {
      expect(dayDiff(DateTime(2026, 3, 30), DateTime(2026, 3, 29)), 1);
      expect(dayDiff(DateTime(2026, 10, 26), DateTime(2026, 10, 25)), 1);
      expect(dayDiff(DateTime(2026, 10, 10), DateTime(2026, 10, 8)), 2);
    });

    test('consecutive days extend the streak', () async {
      await MemoryStore.recordStreakDay(DateTime(2026, 10, 1));
      final s = await MemoryStore.recordStreakDay(DateTime(2026, 10, 2));
      expect(s.streak, 2);
    });

    test('future-stamped entries are pruned on record', () async {
      await MemoryStore.saveStreakStateDirect(
        history: [DateTime(2026, 10, 8), DateTime(2026, 10, 20)],
        streak: 5,
        bestStreak: 5,
        engrams: 0,
      );
      final s = await MemoryStore.recordStreakDay(DateTime(2026, 10, 10));
      expect(
        s.history.any((d) => d.isAfter(DateTime(2026, 10, 10))),
        isFalse,
      );
      expect(s.streak, 1);
    });
  });

  group('engram economy loop', () {
    test('each recorded day earns a fixed amount, once', () async {
      await MemoryStore.recordStreakDay(DateTime(2026, 10, 5));
      await MemoryStore.recordStreakDay(DateTime(2026, 10, 5, 23, 59));
      final s = await MemoryStore.loadStreakState();
      expect(s.streak, 1);
      expect(s.engrams, 20);
    });

    test('23 consecutive days afford one restore', () async {
      for (var i = 0; i < 23; i++) {
        await MemoryStore.recordStreakDay(DateTime(2026, 9, 1 + i));
      }
      var s = await MemoryStore.loadStreakState();
      expect(s.streak, 23);
      expect(s.engrams, 460);
      final outcome = await MemoryStore.restoreStreak(DateTime(2026, 9, 25));
      expect(outcome, StreakRestoreOutcome.restored);
      s = await MemoryStore.loadStreakState();
      expect(s.engrams, 10);
      expect(s.streak, 24);
    });
  });

  group('BattleRating invariants', () {
    test('constants', () {
      expect(BattleRating.startingRating, 1000);
      expect(BattleRating.minRating, 0);
      expect(BattleRating.matchWindow, 60);
      expect(BattleRating.kFactor, 32);
    });

    test('expectedScore anchors', () {
      expect(BattleRating.expectedScore(player: 1000, opponent: 1000), 0.5);
      expect(
        BattleRating.expectedScore(player: 1400, opponent: 1000),
        closeTo(0.909, 0.001),
      );
    });

    test('win > draw > loss, loss floored at 0', () {
      final win = BattleRating.nextRating(
        player: 1000,
        opponent: 1000,
        score: 1,
      );
      final draw = BattleRating.nextRating(
        player: 1000,
        opponent: 1000,
        score: 0.5,
      );
      final loss = BattleRating.nextRating(
        player: 1000,
        opponent: 1000,
        score: 0,
      );
      expect(win, greaterThan(draw));
      expect(draw, greaterThan(loss));
      expect(BattleRating.nextRating(player: 0, opponent: 0, score: 0), 0);
    });
  });

  group('collectibles single-currency invariant', () {
    test('exactly one currency, unknown ids fall back', () {
      expect(collectibles, hasLength(1));
      expect(collectibles.first.id, 'engram');
      expect(collectibleById('engram').id, 'engram');
      expect(collectibleById('nope').id, 'engram');
    });
  });
}
