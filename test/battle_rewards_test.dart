import 'package:engrammo/models/battle_match.dart';
import 'package:engrammo/models/battle_rewards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daily first win', () {
    final day = DateTime(2026, 10, 29, 20, 15);

    test('day keys are stable within a day', () {
      expect(BattleRewards.dayKey(day), '2026-10-29');
      expect(
        BattleRewards.dayKey(day.add(const Duration(hours: 2))),
        '2026-10-29',
      );
      expect(
        BattleRewards.dayKey(day.add(const Duration(days: 1))),
        '2026-10-30',
      );
    });

    test('first win of the day doubles the base XP', () {
      expect(
        BattleRewards.dailyWinBonus(
          baseXp: 112,
          lastWinDay: '',
          now: day,
        ),
        112,
      );
      expect(
        BattleRewards.dailyWinBonus(
          baseXp: 112,
          lastWinDay: '2026-10-28',
          now: day,
        ),
        112,
      );
    });

    test('second win on the same day grants nothing', () {
      expect(
        BattleRewards.dailyWinBonus(
          baseXp: 112,
          lastWinDay: '2026-10-29',
          now: day,
        ),
        0,
      );
    });

    test('non-positive base XP never grants', () {
      expect(
        BattleRewards.dailyWinBonus(baseXp: 0, lastWinDay: '', now: day),
        0,
      );
      expect(
        BattleRewards.dailyWinBonus(baseXp: -5, lastWinDay: '', now: day),
        0,
      );
    });
  });

  group('streak and season payouts', () {
    test('a 3-win streak pays +25 XP', () {
      expect(BattleRewards.streakBonusFor(1), 0);
      expect(BattleRewards.streakBonusFor(2), 0);
      expect(BattleRewards.streakBonusFor(3), 25);
      expect(BattleRewards.streakBonusFor(4), 0);
    });

    test('weekly top3 pays 150, 100 and 50 XP', () {
      expect(BattleRewards.weeklyRankBonusFor(1), 150);
      expect(BattleRewards.weeklyRankBonusFor(2), 100);
      expect(BattleRewards.weeklyRankBonusFor(3), 50);
      expect(BattleRewards.weeklyRankBonusFor(0), 0);
      expect(BattleRewards.weeklyRankBonusFor(4), 0);
      expect(BattleRewards.weeklyRankBonusFor(31), 0);
    });

    test('tier promotion pays +100 XP', () {
      expect(
        BattleRewards.tierUpBonusFor(oldTierIndex: 2, newTierIndex: 3),
        100,
      );
      expect(
        BattleRewards.tierUpBonusFor(oldTierIndex: 2, newTierIndex: 2),
        0,
      );
      expect(
        BattleRewards.tierUpBonusFor(oldTierIndex: 2, newTierIndex: 1),
        0,
      );
    });

    test('season grants combine rank and tier with stable ids', () {
      final now = DateTime(2026, 11, 2, 9);
      final grants = BattleRewards.seasonGrants(
        seasonId: '2026-10-26',
        playerRank: 1,
        oldTierIndex: 2,
        newTierIndex: 3,
        now: now,
      );
      expect(grants, hasLength(2));
      expect(grants[0].id, 'season:2026-10-26:rank');
      expect(grants[0].kind, RewardKind.weekly);
      expect(grants[0].xp, 150);
      expect(grants[1].id, 'season:2026-10-26:tier');
      expect(grants[1].kind, RewardKind.tier);
      expect(grants[1].xp, 100);

      final empty = BattleRewards.seasonGrants(
        seasonId: '2026-10-26',
        playerRank: 12,
        oldTierIndex: 2,
        newTierIndex: 2,
        now: now,
      );
      expect(empty, isEmpty);
    });
  });

  group('anti-idle cap', () {
    test('zero answered questions pays only the floor', () {
      expect(BattleRewards.capIdleXp(150, answered: 0), 5);
      expect(
        BattleRewards.capIdleXp(150, answered: 0),
        BattleXp.participationFloor,
      );
    });

    test('answered duels pass through untouched', () {
      expect(BattleRewards.capIdleXp(150, answered: 1), 150);
      expect(BattleRewards.capIdleXp(30, answered: 3), 30);
    });
  });

  group('reward ledger', () {
    test('unknown kinds fall back to daily', () {
      expect(rewardKindFromName('nope'), RewardKind.daily);
      expect(rewardKindFromName('tier'), RewardKind.tier);
    });

    test('grants and state survive a json round trip', () {
      final grant = RewardGrant(
        id: 'daily:2026-10-29',
        kind: RewardKind.daily,
        xp: 112,
        at: DateTime(2026, 10, 29, 20, 15),
      );
      final back = RewardGrant.fromJson(grant.toJson());
      expect(back.id, 'daily:2026-10-29');
      expect(back.kind, RewardKind.daily);
      expect(back.xp, 112);

      final state = BattleRewardState(grants: [grant]);
      final stateBack = BattleRewardState.fromJson(state.toJson());
      expect(stateBack.grants, hasLength(1));
      expect(stateBack.totalBonusXp, 112);
      expect(stateBack.bonusFor(RewardKind.daily), 112);
      expect(stateBack.bonusFor(RewardKind.tier), 0);
    });

    test('duplicate grant ids are ignored', () {
      final now = DateTime(2026, 10, 29, 20, 15);
      var state = const BattleRewardState();
      state = state.withGrant(
        RewardGrant(id: 'daily:2026-10-29', kind: RewardKind.daily, xp: 50, at: now),
      );
      final same = state.withGrant(
        RewardGrant(id: 'daily:2026-10-29', kind: RewardKind.daily, xp: 50, at: now),
      );
      expect(identical(same, state), isTrue);
      expect(state.totalBonusXp, 50);
      expect(state.hasGrant('daily:2026-10-29'), isTrue);
      expect(state.hasGrant('season:x:rank'), isFalse);
    });
  });
}
