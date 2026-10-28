import 'dart:math' as math;

/// Sima, név nélküli battle pontszám, Elo-szerű mozgással.
///
/// - Mindenki [startingRating]-ről indul.
/// - Vereséggel is csak [minRating]-ig lehet esni (0 alá nem megy).
/// - Győzelem / döntetlen / vereség a klasszikus Elo-képlettel mozgat.
class BattleRating {
  /// Alapérték, ahonnan mindenki indul.
  static const int startingRating = 1000;

  /// Alsó határ: ennél kevesebb nem lehet.
  static const int minRating = 0;

  /// Párosítási sáv: a meccskereső ezen belül keres ellenfelet.
  static const int matchWindow = 60;

  /// K-faktor: egy meccs maximális elmozdulása nagyjából ennyi pont.
  static const int kFactor = 32;

  /// Esély a [player] szemszögéből [opponent] ellen (0..1).
  static double expectedScore({required int player, required int opponent}) {
    return 1 / (1 + math.pow(10, (opponent - player) / 400));
  }

  /// Új pontszám egy lejátszott meccs után.
  ///
  /// [score]: 1.0 győzelem, 0.5 döntetlen, 0.0 vereség.
  /// Az eredményt [minRating]-re vágjuk, felfelé nincs korlát.
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
