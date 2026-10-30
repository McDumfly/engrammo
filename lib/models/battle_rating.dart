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
