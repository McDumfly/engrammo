import 'dart:math';

import 'package:engrammo/models/battle_bot.dart';
import 'package:engrammo/models/battle_match.dart';
import 'package:engrammo/models/battle_round.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:flutter_test/flutter_test.dart';

MetaTask _task({
  String paradigm = 'iconic-probe',
  List<String> items = const ['4', '1', '7'],
  List<String> options = const ['1', '4', '7', '9'],
  int correct = 0,
  String prompt = 'Memorize!',
  String question = 'What was it?',
}) {
  return MetaTask(
    prompt: prompt,
    items: items,
    question: question,
    options: options,
    correct: correct,
    paradigm: paradigm,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('battle round plan', () {
    test('request kinds cover all six memory kinds', () {
      expect(battleRequestKinds, hasLength(6));
      expect(battleRequestKindFor(0), 'sensory');
      expect(battleRequestKindFor(5), 'semantic');
    });

    test('kind index clamps instead of crashing', () {
      expect(battleRequestKindFor(-3), 'sensory');
      expect(battleRequestKindFor(99), 'semantic');
    });

    test('response formats: recall everywhere except semantic judgment', () {
      expect(
        battleResponseKindForRequest('working'),
        BattleResponseKind.typedDigits,
      );
      expect(
        battleResponseKindForRequest('pattern'),
        BattleResponseKind.cellSet,
      );
      expect(
        battleResponseKindForRequest('semantic'),
        BattleResponseKind.choice4,
      );
      for (final k in ['sensory', 'visual', 'verbal']) {
        expect(
          battleResponseKindForRequest(k),
          BattleResponseKind.typedToken,
          reason: k,
        );
      }
    });

    test('round plan starts chosen then interleaves two other kinds', () {
      for (var chosen = 0; chosen < 6; chosen++) {
        final plan = battleRoundKinds(chosen);
        expect(plan, hasLength(3));
        expect(plan.first, chosen);
        expect(plan.toSet(), hasLength(3), reason: 'chosen=$chosen');
      }
      expect(battleRoundKinds(0), [0, 2, 4]);
      expect(battleRoundKinds(5), [5, 1, 3]);
    });
  });

  group('battle clocks', () {
    test('encode time grows with load, judgment needs none', () {
      final iconic = _task(paradigm: 'iconic-probe');
      expect(
        battleEncodeMs(iconic, difficulty: 2),
        lessThan(battleEncodeMs(iconic, difficulty: 4)),
      );
      final short = _task(paradigm: 'backward-span', items: ['1', '2', '3']);
      final long = _task(
        paradigm: 'backward-span',
        items: ['1', '2', '3', '4', '5'],
      );
      expect(
        battleEncodeMs(short, difficulty: 2),
        lessThan(battleEncodeMs(long, difficulty: 2)),
      );
      expect(
        battleEncodeMs(_task(paradigm: 'category-exemplar'), difficulty: 3),
        0,
      );
    });

    test('typed recall gets the longest clock', () {
      expect(
        battleRecallMs(BattleResponseKind.typedToken),
        battleRecallMs(BattleResponseKind.typedDigits),
      );
      expect(
        battleRecallMs(BattleResponseKind.typedToken),
        greaterThan(battleRecallMs(BattleResponseKind.cellSet)),
      );
      expect(
        battleRecallMs(BattleResponseKind.cellSet),
        greaterThan(battleRecallMs(BattleResponseKind.choice4)),
      );
    });
  });

  group('blind encode + keys', () {
    test('backward span hides the reverse instruction until recall', () {
      final task = _task(
        paradigm: 'backward-span',
        prompt: 'Hold these digits, then reverse them!',
      );
      final encode = battleEncodePrompt(task);
      expect(encode.toLowerCase(), isNot(contains('revers')));
      expect(encode, contains('direction comes next'));
    });

    test('other paradigms keep their own encode prompt', () {
      final task = _task(paradigm: 'iconic-probe', prompt: 'One quick look!');
      expect(battleEncodePrompt(task), 'One quick look!');
    });

    test('answer key reads the validated option, empty when out of range', () {
      expect(battleAnswerKey(_task()), '1');
      expect(battleAnswerKey(_task(correct: 9)), '');
    });

    test('expected cells parse 0-8 only', () {
      final task = _task(paradigm: 'pattern-span', items: ['1', '4', 'x', '9']);
      expect(battleExpectedCells(task), [1, 4]);
    });
  });

  group('battleScoreResponse', () {
    test('iconic digit is exact-only (single chars never fuzzy-match)', () {
      final task = _task();
      expect(battleScoreResponse(task, text: '1').exact, isTrue);
      expect(battleScoreResponse(task, text: '2').proportion, 0);
    });

    test('backward span scores positional partial credit', () {
      final task = _task(
        paradigm: 'backward-span',
        items: ['8', '2', '5'],
        options: ['5-2-8', '8-2-5', '2-5-8', '5-8-2'],
        correct: 0,
      );
      final exact = battleScoreResponse(task, text: '528');
      expect(exact.exact, isTrue);
      final partial = battleScoreResponse(task, text: '52');
      expect(partial.exact, isFalse);
      expect(partial.proportion, closeTo(2 / 3, 0.001));
    });

    test('pattern taps penalize false alarms', () {
      final task = _task(paradigm: 'pattern-span', items: ['1', '4', '7']);
      expect(
        battleScoreResponse(task, taps: [1, 4, 7]).exact,
        isTrue,
      );
      final extra = battleScoreResponse(task, taps: [1, 4, 7, 0]);
      expect(extra.exact, isFalse);
      expect(extra.proportion, lessThan(1.0));
      expect(battleScoreResponse(task, taps: const []).proportion, 0);
    });

    test('paired target is typo-tolerant but not exact on typos', () {
      final task = _task(
        paradigm: 'paired-associate',
        items: ['candle → garden'],
        options: ['garden', 'river', 'tower', 'cloud'],
        correct: 0,
      );
      expect(battleScoreResponse(task, text: 'garden').exact, isTrue);
      final typo = battleScoreResponse(task, text: 'gardem');
      expect(typo.proportion, 1.0);
      expect(typo.exact, isFalse);
    });
  });

  group('battleResponsePresent', () {
    test('blank typing and zero taps count as unanswered', () {
      expect(
        battleResponsePresent(BattleResponseKind.typedToken, text: '  '),
        isFalse,
      );
      expect(
        battleResponsePresent(BattleResponseKind.cellSet, taps: const []),
        isFalse,
      );
      expect(
        battleResponsePresent(BattleResponseKind.choice4, choice: -1),
        isFalse,
      );
      expect(
        battleResponsePresent(BattleResponseKind.typedDigits, text: '52'),
        isTrue,
      );
      expect(
        battleResponsePresent(BattleResponseKind.cellSet, taps: [3]),
        isTrue,
      );
      expect(
        battleResponsePresent(BattleResponseKind.choice4, choice: 2),
        isTrue,
      );
    });
  });

  group('tiered recall scoring', () {
    int pts(double p, bool exact, [int ms = 5000]) =>
        BattleScore.questionPoints(
          correct: p >= 0.5 || exact,
          latencyMs: ms,
          clockMs: 30000,
          proportion: p,
          exact: exact,
        );

    test('exact earns 100 plus speed, faster beats slower', () {
      final fast = pts(1.0, true, 1000);
      final slow = pts(1.0, true, 29000);
      expect(fast, greaterThan(100));
      expect(slow, greaterThanOrEqualTo(100));
      expect(fast, greaterThan(slow));
      expect(fast, lessThanOrEqualTo(150));
    });

    test('partial tiers have no speed bonus', () {
      expect(pts(1.0, false, 100), 75);
      expect(pts(1.0, false, 29000), 75);
      expect(pts(0.8, false), 60);
      expect(pts(0.75, false), 60);
      expect(pts(0.5, false), 40);
      expect(pts(0.49, false), 0);
      expect(pts(0.0, false), 0);
    });

    test('legacy binary path is untouched', () {
      expect(
        BattleScore.questionPoints(correct: true, latencyMs: 1000),
        greaterThan(100),
      );
      expect(BattleScore.questionPoints(correct: false, latencyMs: 500), 0);
    });
  });

  group('round record exact flags', () {
    test('exact flags round-trip through JSON', () {
      const record = BattleRoundRecord(
        question: 'q',
        playerCorrect: true,
        foeCorrect: true,
        playerMs: 100,
        foeMs: 200,
        playerPts: 120,
        foePts: 60,
        playerExact: true,
        foeExact: false,
      );
      final back = BattleRoundRecord.fromJson(record.toJson());
      expect(back.playerExact, isTrue);
      expect(back.foeExact, isFalse);
    });

    test('old records without exact flags fall back to correct flags', () {
      final back = BattleRoundRecord.fromJson({
        'question': 'q',
        'playerCorrect': true,
        'foeCorrect': false,
        'playerMs': 0,
        'foeMs': 0,
        'playerPts': 0,
        'foePts': 0,
      });
      expect(back.playerExact, isTrue);
      expect(back.foeExact, isFalse);
    });
  });

  group('bot recall simulation', () {
    BotPersona botForTier(BotTier tier) {
      final spec = specForTier(tier);
      return BotPersona(
        id: 't:${tier.name}',
        name: tier.name,
        rating: spec.minRating,
        xp: 0,
        streak: 0,
        avatarSeed: 0,
      );
    }

    test('harder paradigms lower the exact probability', () {
      final bot = botForTier(BotTier.sharp);
      final easy = botRecallExactProb(
        bot: bot,
        kind: 1,
        paradigm: 'iconic-probe',
      );
      final hard = botRecallExactProb(
        bot: bot,
        kind: 1,
        paradigm: 'backward-span',
      );
      expect(easy, greaterThan(hard));
      expect(hard, inInclusiveRange(0.05, 0.98));
    });

    test('stronger tiers beat weaker tiers on the same paradigm', () {
      // No per-kind bias here: the deterministic ±0.08 kind bias can exceed
      // the gap between adjacent band edges (pre-existing botAccuracy rule).
      var prev = 0.0;
      for (final tier in BotTier.values) {
        final p = botRecallExactProb(
          bot: botForTier(tier),
          paradigm: 'pattern-span',
        );
        expect(p, greaterThanOrEqualTo(prev), reason: tier.name);
        prev = p;
      }
    });

    test('partial bases stay inside the 75/60/40 tiers', () {
      for (final tier in BotTier.values) {
        for (var i = 0; i < 20; i++) {
          expect(
            botPartialBase(tier, i / 20),
            anyOf(75, 60, 40),
            reason: '$tier $i',
          );
        }
        // Representative proportions map back to the same tier.
        expect(botPartialProportion(75), 1.0);
        expect(
          BattleScore.questionPoints(
            correct: true,
            latencyMs: 99999,
            proportion: botPartialProportion(60),
            exact: false,
          ),
          60,
        );
        expect(
          BattleScore.questionPoints(
            correct: true,
            latencyMs: 0,
            proportion: botPartialProportion(40),
            exact: false,
          ),
          40,
        );
      }
    });

    test('recall outcomes are deterministic per seed and bounded', () {
      BotPersona bot = botForTier(BotTier.master);
      List<int> run(int seed) {
        final rng = Random(seed);
        return [
          for (var i = 0; i < 6; i++)
            botRecallOutcome(
              bot: bot,
              kind: 1,
              paradigm: 'backward-span',
              rng: rng,
              clockMs: 30000,
            ).base,
        ];
      }

      expect(run(42), run(42));
      for (final base in run(7)) {
        expect(base, anyOf(0, 40, 60, 75, 100));
      }
      final out = botRecallOutcome(
        bot: bot,
        kind: 1,
        paradigm: 'backward-span',
        rng: Random(1),
        clockMs: 30000,
      );
      expect(out.latencyMs, inInclusiveRange(800, 30000));
      // Exact and base always agree.
      expect(out.exact, out.base == 100);
    });
  });
}
