import 'dart:math';

import '../l10n/app_localizations.dart';

/// Duel outcome from the player's point of view.
enum BattleOutcome { win, loss, draw }

/// Parses a persisted outcome name. Returns null for unknown input so old
/// records without a stored outcome fall back to score comparison.
BattleOutcome? battleOutcomeFromName(String? name) {
  for (final outcome in BattleOutcome.values) {
    if (outcome.name == name) return outcome;
  }
  return null;
}

/// Outcome for two totals. Ties on points are broken by faster total
/// latency, mirroring the assessment's fastest-latency tiebreak.
BattleOutcome outcomeFor(
  int playerTotal,
  int foeTotal, {
  int playerMs = 0,
  int foeMs = 0,
}) {
  if (playerTotal != foeTotal) {
    return playerTotal > foeTotal ? BattleOutcome.win : BattleOutcome.loss;
  }
  if (playerMs == foeMs) return BattleOutcome.draw;
  return playerMs < foeMs ? BattleOutcome.win : BattleOutcome.loss;
}

/// Raw memory-growth base (0-3) for a finished duel.
///
/// Wins pay up to 3, draws 1, losses 0, scaled by the share of exact
/// player rounds: (outcomeBase * exact / rounds).round(). Pure.
int battleGrowthBase({
  required BattleOutcome outcome,
  required int exact,
  required int rounds,
}) {
  final outcomeBase = switch (outcome) {
    BattleOutcome.win => 3,
    BattleOutcome.draw => 1,
    BattleOutcome.loss => 0,
  };
  if (outcomeBase <= 0 || rounds <= 0 || exact <= 0) return 0;
  return (outcomeBase * exact / rounds).round();
}

/// Per-question duel scoring.
///
/// Binary rounds (4-option judgment): 100 for correct plus a linear speed
/// bonus of up to 50. Wrong answers and timeouts score 0.
///
/// Recall rounds (typed/grid, [proportion] set): quantized partial-credit
/// tiers — exact 100, full-content-with-typo 75, near-miss 60,
/// half-remembered 40, below half 0. The speed bonus applies ONLY to exact
/// answers, so fast garbage can never farm partial points plus speed.
class BattleScore {
  static const int correctPoints = 100;
  static const int maxSpeedBonus = 50;
  static const int questionClockMs = 20000;

  static int questionPoints({
    required bool correct,
    required int latencyMs,
    int clockMs = questionClockMs,
    double? proportion,
    bool? exact,
  }) {
    if (proportion == null) {
      if (!correct) return 0;
      return correctPoints + _speedBonus(latencyMs, clockMs);
    }
    final p = proportion.clamp(0.0, 1.0);
    final isExact = exact ?? false;
    final base = isExact
        ? 100
        : p >= 1.0
        ? 75
        : p >= 0.75
        ? 60
        : p >= 0.5
        ? 40
        : 0;
    if (base <= 0) return 0;
    if (!isExact) return base;
    return base + _speedBonus(latencyMs, clockMs);
  }

  static int _speedBonus(int latencyMs, int clockMs) {
    final clamped = latencyMs.clamp(0, clockMs);
    return ((clockMs - clamped) / clockMs * maxSpeedBonus).round().clamp(
      0,
      maxSpeedBonus,
    );
  }
}

/// Battle XP wallet. Feeds the league board and the profile total.
class BattleXp {
  static const int winBase = 100;
  static const int drawBase = 60;
  static const int lossBase = 30;
  static const int participationFloor = 5;
  static const int fastestBonus = 10;

  /// XP for one finished duel. Wins scale with the margin (capped), draws
  /// and losses pay flat, each fastest-answer bonus adds +10.
  static int forOutcome({
    required BattleOutcome outcome,
    required int margin,
    int fastestBonuses = 0,
  }) {
    var xp = switch (outcome) {
      BattleOutcome.win => winBase + (margin ~/ 10).clamp(0, 50),
      BattleOutcome.draw => drawBase,
      BattleOutcome.loss => lossBase,
    };
    xp += fastestBonus * fastestBonuses.clamp(0, 8);
    return max(participationFloor, xp);
  }
}

/// One duel question from both sides.
class BattleRoundRecord {
  final String question;
  final bool playerCorrect;
  final bool foeCorrect;
  final int playerMs;
  final int foeMs;
  final int playerPts;
  final int foePts;

  /// Exact-recall flags for recall rounds (no typo, no extra/missing unit).
  /// Old records without these fields fall back to the correct flags.
  final bool playerExact;
  final bool foeExact;

  const BattleRoundRecord({
    required this.question,
    required this.playerCorrect,
    required this.foeCorrect,
    required this.playerMs,
    required this.foeMs,
    required this.playerPts,
    required this.foePts,
    this.playerExact = false,
    this.foeExact = false,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'playerCorrect': playerCorrect,
    'foeCorrect': foeCorrect,
    'playerMs': playerMs,
    'foeMs': foeMs,
    'playerPts': playerPts,
    'foePts': foePts,
    'playerExact': playerExact,
    'foeExact': foeExact,
  };

  factory BattleRoundRecord.fromJson(Map<String, dynamic> json) {
    final playerCorrect = (json['playerCorrect'] as bool?) ?? false;
    final foeCorrect = (json['foeCorrect'] as bool?) ?? false;
    return BattleRoundRecord(
      question: (json['question'] as String?) ?? '',
      playerCorrect: playerCorrect,
      foeCorrect: foeCorrect,
      playerMs: (json['playerMs'] as num?)?.toInt() ?? 0,
      foeMs: (json['foeMs'] as num?)?.toInt() ?? 0,
      playerPts: (json['playerPts'] as num?)?.toInt() ?? 0,
      foePts: (json['foePts'] as num?)?.toInt() ?? 0,
      playerExact: (json['playerExact'] as bool?) ?? playerCorrect,
      foeExact: (json['foeExact'] as bool?) ?? foeCorrect,
    );
  }
}

/// One finished (or forfeited) duel, persisted to the match history.
class BattleRecord {
  final String id;
  final DateTime at;
  final String opponent;
  final int opponentRating;
  final bool duel;
  final int kind;
  final int playerScore;
  final int foeScore;
  final List<BattleRoundRecord> rounds;
  final List<String> roundLines;
  final int delta;
  final int xp;
  final bool forfeit;
  final BattleOutcome? decidedOutcome;

  const BattleRecord({
    required this.id,
    required this.at,
    required this.opponent,
    required this.opponentRating,
    required this.duel,
    required this.kind,
    required this.playerScore,
    required this.foeScore,
    required this.rounds,
    required this.roundLines,
    required this.delta,
    required this.xp,
    this.forfeit = false,
    this.decidedOutcome,
  });

  /// The outcome decided at match end. Stored explicitly because latency
  /// tiebreaks can decide equal-score duels; old records without a stored
  /// outcome fall back to plain score comparison.
  BattleOutcome get outcome =>
      decidedOutcome ??
      (forfeit ? BattleOutcome.loss : outcomeFor(playerScore, foeScore));

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'opponent': opponent,
    'opponentRating': opponentRating,
    'duel': duel,
    'kind': kind,
    'playerScore': playerScore,
    'foeScore': foeScore,
    'rounds': [for (final r in rounds) r.toJson()],
    'roundLines': roundLines,
    'delta': delta,
    'xp': xp,
    'forfeit': forfeit,
    'outcome': decidedOutcome?.name,
  };

  factory BattleRecord.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return BattleRecord(
      id: (json['id'] as String?) ?? '',
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      opponent: (json['opponent'] as String?) ?? 'Player',
      opponentRating: (json['opponentRating'] as num?)?.toInt() ?? 1000,
      duel: (json['duel'] as bool?) ?? true,
      kind: (json['kind'] as num?)?.toInt() ?? 0,
      playerScore: (json['playerScore'] as num?)?.toInt() ?? 0,
      foeScore: (json['foeScore'] as num?)?.toInt() ?? 0,
      rounds: [
        for (final e in (json['rounds'] as List? ?? const []))
          if (e is Map<String, dynamic>) BattleRoundRecord.fromJson(e),
      ],
      roundLines: [
        for (final e in (json['roundLines'] as List? ?? const [])) e.toString(),
      ],
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      forfeit: (json['forfeit'] as bool?) ?? false,
      decidedOutcome: battleOutcomeFromName(json['outcome'] as String?),
    );
  }
}

/// Aggregate duel stats shown in the Battle Zone header cards.
class BattleStats {
  final int matches;
  final int wins;
  final int losses;
  final int draws;
  final int bestStreak;
  final int currentStreak;

  const BattleStats({
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
  });

  double get winRate => matches == 0 ? 0 : wins / matches;

  String get winRateLabel => matches == 0 ? '–' : '${(winRate * 100).round()}%';

  String get bestStreakLabel => matches == 0 ? '–' : '$bestStreak';

  BattleStats record(BattleOutcome outcome) {
    final streak = outcome == BattleOutcome.win ? currentStreak + 1 : 0;
    return BattleStats(
      matches: matches + 1,
      wins: wins + (outcome == BattleOutcome.win ? 1 : 0),
      losses: losses + (outcome == BattleOutcome.loss ? 1 : 0),
      draws: draws + (outcome == BattleOutcome.draw ? 1 : 0),
      bestStreak: max(bestStreak, streak),
      currentStreak: streak,
    );
  }

  Map<String, dynamic> toJson() => {
    'matches': matches,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'bestStreak': bestStreak,
    'currentStreak': currentStreak,
  };

  factory BattleStats.fromJson(Map<String, dynamic> json) {
    return BattleStats(
      matches: (json['matches'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Short match date label: 'Today, 19:42', 'Yesterday, 20:15' or
/// 'Oct 23, 20:15'. Pure so history rows render without intl.
String battleDateLabel(DateTime at, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(n.year, n.month, n.day);
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today, $hh:$mm';
  if (diff == 1) return 'Yesterday, $hh:$mm';
  return '${_months[at.month - 1]} ${at.day}, $hh:$mm';
}

String battleDateLabelIn(String locale, DateTime at, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(n.year, n.month, n.day);
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  final diff = today.difference(day).inDays;
  if (diff <= 0) return trFor(locale, 'btl_today', {'t': '$hh:$mm'});
  if (diff == 1) return trFor(locale, 'btl_yesterday', {'t': '$hh:$mm'});
  return trFor(locale, 'btl_date', {
    'mon': trFor(locale, 'btl_mon_${at.month - 1}'),
    'day': at.day,
    't': '$hh:$mm',
  });
}
