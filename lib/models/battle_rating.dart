/// Elo-style duel rating (Elo 1978, "The Rating of Chessplayers").
/// Standard logistic curve with a 400-point scale and K=32 — the same
/// constants chess federations use for developing players — applied here
/// to memory duels. Honesty note: the formula is borrowed, not
/// validated for memory skill; ratings are relative within this app's
/// duel pool (start 1000, floor 0) and measure duel results, not memory
/// ability. Matchmaking pairs opponents within ±60 points.
library;

import 'dart:math' as math;

class BattleRating {
  static const int startingRating = 1000;

  static const int minRating = 0;

  static const int matchWindow = 60;

  static const int kFactor = 32;

  static double expectedScore({required int player, required int opponent}) {
    return 1 / (1 + math.pow(10, (opponent - player) / 400));
  }

  static int nextRating({
    required int player,
    required int opponent,
    required double score,
    int kFactor = BattleRating.kFactor,
  }) {
    final expected = expectedScore(player: player, opponent: opponent);
    final next = (player + kFactor * (score - expected)).round();
    return math.max(minRating, next);
  }

  static int win({required int player, required int opponent}) =>
      nextRating(player: player, opponent: opponent, score: 1);

  static int loss({required int player, required int opponent}) =>
      nextRating(player: player, opponent: opponent, score: 0);

  static int draw({required int player, required int opponent}) =>
      nextRating(player: player, opponent: opponent, score: 0.5);
}
