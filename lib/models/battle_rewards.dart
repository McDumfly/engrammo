import 'battle_match.dart';

/// Battle reward rules: daily first-win double, win-streak bonus, weekly
/// top-3 payouts and tier-promotion bonus.
///
/// Everything here is pure and deterministic, so rewards grant identically
/// offline; [BotArenaStore] persists the resulting [BattleRewardState]
/// through [MemoryStore].
enum RewardKind { daily, streak, weekly, tier }

RewardKind rewardKindFromName(String name) {
  for (final kind in RewardKind.values) {
    if (kind.name == name) return kind;
  }
  return RewardKind.daily;
}

/// One granted bonus. The [id] is stable per cause
/// ('daily:2026-10-29', 'streak:battle:…', 'season:…:rank', 'season:…:tier')
/// so replays and reloads never double-grant.
class RewardGrant {
  final String id;
  final RewardKind kind;
  final int xp;
  final DateTime at;

  const RewardGrant({
    required this.id,
    required this.kind,
    required this.xp,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'xp': xp,
    'at': at.toIso8601String(),
  };

  factory RewardGrant.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return RewardGrant(
      id: (json['id'] as String?) ?? '',
      kind: rewardKindFromName((json['kind'] as String?) ?? 'daily'),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Persisted reward ledger: every bonus granted so far.
class BattleRewardState {
  final List<RewardGrant> grants;

  const BattleRewardState({this.grants = const []});

  bool hasGrant(String id) => grants.any((g) => g.id == id);

  int get totalBonusXp {
    var total = 0;
    for (final g in grants) {
      total += g.xp;
    }
    return total;
  }

  int bonusFor(RewardKind kind) {
    var total = 0;
    for (final g in grants) {
      if (g.kind == kind) total += g.xp;
    }
    return total;
  }

  /// Adds [grant] unless its id was already granted. Returns `this`
  /// unchanged on duplicates so callers stay idempotent.
  BattleRewardState withGrant(RewardGrant grant) {
    if (grant.id.isEmpty || hasGrant(grant.id)) return this;
    return BattleRewardState(grants: [...grants, grant]);
  }

  Map<String, dynamic> toJson() => {
    'grants': [for (final g in grants) g.toJson()],
  };

  factory BattleRewardState.fromJson(Map<String, dynamic> json) {
    return BattleRewardState(
      grants: [
        for (final e in (json['grants'] as List? ?? const []))
          if (e is Map<String, dynamic>) RewardGrant.fromJson(e),
      ],
    );
  }
}

/// Deterministic reward rules. All functions are pure: same inputs always
/// grant the same XP, with no clock or storage access except the explicit
/// [now] parameter.
class BattleRewards {
  /// Daily first win pays double: the bonus equals the duel's base XP.
  static const int dailyWinMultiplier = 2;

  /// Bonus when the post-win streak reaches exactly 3.
  static const int streak3BonusXp = 25;

  /// Bonus on league tier promotion.
  static const int tierUpBonusXp = 100;

  /// Weekly top-3 payouts by 1-based rank.
  static const List<int> weeklyTopXp = <int>[150, 100, 50];

  /// Day key 'yyyy-MM-dd' for daily-bonus bookkeeping.
  static String dayKey(DateTime now) {
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Whether a win on [now] earns the daily first-win double.
  static bool qualifiesDailyFirstWin({
    required String lastWinDay,
    DateTime? now,
  }) {
    return lastWinDay != dayKey(now ?? DateTime.now());
  }

  /// Bonus XP for a won duel with [baseXp]: the full base again (x2
  /// total) on the first win of the day, 0 when already claimed.
  /// Call only for wins; losses and draws never qualify.
  static int dailyWinBonus({
    required int baseXp,
    required String lastWinDay,
    DateTime? now,
  }) {
    if (baseXp <= 0) return 0;
    if (!qualifiesDailyFirstWin(lastWinDay: lastWinDay, now: now)) return 0;
    return baseXp * (dailyWinMultiplier - 1);
  }

  /// +25 XP when the post-win streak reaches exactly 3, else 0.
  static int streakBonusFor(int streakAfterWin) {
    return streakAfterWin == 3 ? streak3BonusXp : 0;
  }

  /// Weekly top-3 payout by 1-based [rank], 0 off the podium.
  static int weeklyRankBonusFor(int rank) {
    if (rank < 1 || rank > weeklyTopXp.length) return 0;
    return weeklyTopXp[rank - 1];
  }

  /// +100 XP on tier promotion, 0 otherwise.
  static int tierUpBonusFor({
    required int oldTierIndex,
    required int newTierIndex,
  }) {
    return newTierIndex > oldTierIndex ? tierUpBonusXp : 0;
  }

  /// Season-end grants: weekly rank payout plus tier-promotion bonus.
  /// Returns an empty list when neither applies.
  static List<RewardGrant> seasonGrants({
    required String seasonId,
    required int playerRank,
    required int oldTierIndex,
    required int newTierIndex,
    required DateTime now,
  }) {
    final out = <RewardGrant>[];
    final rankXp = weeklyRankBonusFor(playerRank);
    if (rankXp > 0) {
      out.add(
        RewardGrant(
          id: 'season:$seasonId:rank',
          kind: RewardKind.weekly,
          xp: rankXp,
          at: now,
        ),
      );
    }
    final tierXp = tierUpBonusFor(
      oldTierIndex: oldTierIndex,
      newTierIndex: newTierIndex,
    );
    if (tierXp > 0) {
      out.add(
        RewardGrant(
          id: 'season:$seasonId:tier',
          kind: RewardKind.tier,
          xp: tierXp,
          at: now,
        ),
      );
    }
    return out;
  }

  /// Anti-idle cap: a duel with zero answered questions pays only the
  /// participation floor, no matter the outcome math.
  static int capIdleXp(int xp, {required int answered}) {
    if (answered <= 0) return BattleXp.participationFloor;
    return xp;
  }
}
