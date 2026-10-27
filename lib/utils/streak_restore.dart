import 'streak_utils.dart';

/// Széria-visszaállítás engramért — a kreeds-app
/// `RewardService` visszaállító logikája helyi modellre szabva.
///
/// Szabályok (megegyeznek a kreeds-appéval):
/// - legfeljebb [maxMissedDays] egymást követő kihagyott nap pótolható;
/// - a visszaállítás a szakadás előtti összefüggő szakaszt folytatja;
/// - a kijelzővel megegyező, naptár-alapú széria dönt mindenhol.
///
/// Eltérés: a kreeds-app napi 200 kreditet kér (1 nap = 200,
/// 2 nap = 400), itt egy visszaállítás fix [restoreCost] engram,
/// függetlenül a pótolt napok számától.
abstract final class StreakRestore {
  /// Egy visszaállítás ára engramban (1 vagy 2 pótolt napra is).
  static const int restoreCost = 450;

  /// Legfeljebb ennyi egymást követő kihagyott nap pótolható.
  static const int maxMissedDays = 2;

  /// A visszaállítás ára a kihagyott napok számából.
  /// Fix ár: 1 és 2 napra is [restoreCost].
  static int streakRestoreCost(int missedDays) {
    assert(missedDays >= 1 && missedDays <= maxMissedDays);
    return restoreCost;
  }

  /// Visszaállítási terv: mely napok pótlódnak, mennyi lesz a széria.
  /// `null` = nincs mit visszaállítani (él a széria, üres a naptár,
  /// vagy túl régi a szakadás). Tiszta függvény, tesztelhető.
  static RestorePlan? planStreakRestore({
    required List<DateTime> history,
    required DateTime today,
  }) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final t = day(today);
    final days = history.map(day).toSet().toList()..sort();
    if (days.isEmpty || days.last.isAfter(t)) return null;

    final todayDone = days.last == t;
    final prev =
        todayDone
            ? (days.length < 2 ? null : days[days.length - 2])
            : days.last;
    if (prev == null) return null;

    final missed = t.difference(prev).inDays - 1;
    if (missed < 1 || missed > maxMissedDays) return null;

    // A szakadás előtti összefüggő szakasz hossza.
    var run = 1;
    for (var i = days.indexOf(prev); i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
      } else {
        break;
      }
    }

    final filled = [
      for (var i = 1; i <= missed; i++) prev.add(Duration(days: i)),
    ];
    return RestorePlan(
      filledDays: filled,
      restoredStreak: run + missed + (todayDone ? 1 : 0),
      lastDate: todayDone ? t : filled.last,
      missedDays: missed,
    );
  }

  /// A pótolt napok napkulcsai ("2026-10-05").
  /// Tiszta függvény, tesztelhető.
  static List<String> restoreDayKeys(RestorePlan plan) =>
      [for (final d in plan.filledDays) dayId(d)];

  /// Törött-e a széria (visszaállítható szakadás van a naptárban)?
  /// Tiszta függvény, tesztelhető.
  static bool isStreakBroken({
    required int stored,
    required List<DateTime> history,
    required DateTime today,
  }) {
    return planStreakRestore(history: history, today: today) != null;
  }

  /// A kijelzendő széria: élő szakasz esetén a naptárból számolt
  /// hossz is számít, így egy tévesen lenullázott számláló sem
  /// mutat 0-t, amíg a tegnapi/mai nap megvan.
  static int displayStreak({
    required int stored,
    required List<DateTime> history,
    required DateTime today,
  }) {
    return effectiveStreak(
      stored: stored,
      history: history,
      today: today,
      maxMissedDays: maxMissedDays,
    );
  }

  /// Felugorhat-e ma a visszaállítás-emlékeztető?
  /// Tiszta függvény, tesztelhető.
  static bool shouldShowRestorePrompt({
    required String? lastPromptDay,
    required String todayKey,
  }) {
    return lastPromptDay != todayKey;
  }
}

/// Egy széria-visszaállítás kiszámolt eredménye.
class RestorePlan {
  const RestorePlan({
    required this.filledDays,
    required this.restoredStreak,
    required this.lastDate,
    required this.missedDays,
  });

  /// A naptárba utólag beírt kihagyott napok.
  final List<DateTime> filledDays;

  /// A visszaállítás utáni szériahossz.
  final int restoredStreak;

  /// Az utolsó szérianap (ma, ha mára már teljesítettek).
  final DateTime lastDate;

  /// Hány napot pótolunk.
  final int missedDays;
}

/// A visszaállítás kimenetele.
enum StreakRestoreOutcome { restored, notEligible, insufficientFunds }
