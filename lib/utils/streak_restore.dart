import 'streak_utils.dart';

abstract final class StreakRestore {
  static const int restoreCost = 450;

  static const int maxMissedDays = 2;

  static int streakRestoreCost(int missedDays) {
    assert(missedDays >= 1 && missedDays <= maxMissedDays);
    return restoreCost;
  }

  static RestorePlan? planStreakRestore({
    required List<DateTime> history,
    required DateTime today,
  }) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final t = day(today);
    final days = history.map(day).toSet().toList()..sort();
    if (days.isEmpty || days.last.isAfter(t)) return null;

    final todayDone = days.last == t;
    final prev = todayDone
        ? (days.length < 2 ? null : days[days.length - 2])
        : days.last;
    if (prev == null) return null;

    final missed = dayDiff(t, prev) - 1;
    if (missed < 1 || missed > maxMissedDays) return null;

    var run = 1;
    for (var i = days.indexOf(prev); i > 0; i--) {
      if (dayDiff(days[i], days[i - 1]) == 1) {
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

  static List<String> restoreDayKeys(RestorePlan plan) => [
    for (final d in plan.filledDays) dayId(d),
  ];

  static bool isStreakBroken({
    required int stored,
    required List<DateTime> history,
    required DateTime today,
  }) {
    return planStreakRestore(history: history, today: today) != null;
  }

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

  static bool shouldShowRestorePrompt({
    required String? lastPromptDay,
    required String todayKey,
  }) {
    return lastPromptDay != todayKey;
  }
}

class RestorePlan {
  const RestorePlan({
    required this.filledDays,
    required this.restoredStreak,
    required this.lastDate,
    required this.missedDays,
  });

  final List<DateTime> filledDays;

  final int restoredStreak;

  final DateTime lastDate;

  final int missedDays;
}

enum StreakRestoreOutcome { restored, notEligible, insufficientFunds }
