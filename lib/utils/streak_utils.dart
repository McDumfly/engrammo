import 'dart:math';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int dayDiff(DateTime a, DateTime b) {
  final x = DateTime.utc(a.year, a.month, a.day);
  final y = DateTime.utc(b.year, b.month, b.day);
  return x.difference(y).inDays;
}

DateTime? parseStreakDate(Object? entry) {
  if (entry == null) return null;
  if (entry is DateTime) return _day(entry);
  if (entry is int) {
    try {
      return _day(DateTime.fromMillisecondsSinceEpoch(entry));
    } catch (_) {
      return null;
    }
  }
  if (entry is String) {
    final parsed = DateTime.tryParse(entry);
    return parsed == null ? null : _day(parsed);
  }
  if (entry is Map) {
    final seconds =
        entry['seconds'] ?? entry['_seconds'] ?? entry['secondsSinceEpoch'];
    if (seconds is num) {
      final nanos = entry['nanoseconds'] ?? entry['_nanoseconds'] ?? 0;
      final millis =
          seconds.toInt() * 1000 +
          ((nanos is num ? nanos.toInt() : 0) ~/ 1000000);
      try {
        return _day(DateTime.fromMillisecondsSinceEpoch(millis));
      } catch (_) {
        return null;
      }
    }
    final millis = entry['millisecondsSinceEpoch'];
    if (millis is num) {
      try {
        return _day(DateTime.fromMillisecondsSinceEpoch(millis.toInt()));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  try {
    final converted = (entry as dynamic).toDate();
    if (converted is DateTime) return _day(converted);
  } catch (_) {
  }
  return null;
}

List<DateTime> parseStreakHistory(Object? raw) {
  if (raw is! List) return const [];
  final days = <DateTime>{};
  for (final entry in raw) {
    final parsed = parseStreakDate(entry);
    if (parsed != null) days.add(parsed);
  }
  final sorted = days.toList()..sort();
  return sorted;
}

int currentRunLength({
  required List<DateTime> history,
  required DateTime today,
}) {
  if (history.isEmpty) return 0;
  final t = _day(today);
  final days = history.map(_day).toSet().toList()..sort();
  final last = days.last;
  final gap = dayDiff(t, last);
  if (gap < 0 || gap > 1) return 0;
  var run = 1;
  var cursor = last;
  for (var i = days.length - 2; i >= 0; i--) {
    if (dayDiff(cursor, days[i]) == 1) {
      run++;
      cursor = days[i];
    } else {
      break;
    }
  }
  return run;
}

int maxRunLength(List<DateTime> history) {
  if (history.isEmpty) return 0;
  final days = history.map(_day).toSet().toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (dayDiff(days[i], days[i - 1]) == 1) {
      run++;
      best = max(best, run);
    } else {
      run = 1;
    }
  }
  return best;
}

int effectiveStreak({
  required int stored,
  required List<DateTime> history,
  required DateTime today,
  required int maxMissedDays,
}) {
  final safeStored = stored < 0 ? 0 : stored;
  final run = currentRunLength(history: history, today: today);
  if (run > 0) return max(safeStored, run);
  if (history.isEmpty) return safeStored;
  final lastDay = history.map(_day).toList()..sort();
  if (!streakGraceExpired(
    lastDay: lastDay.last,
    today: today,
    maxMissedDays: maxMissedDays,
  )) {
    return safeStored;
  }
  return 0;
}

DateTime? latestStreakDay({DateTime? stamped, DateTime? historyLast}) {
  if (stamped == null) return historyLast;
  if (historyLast == null) return stamped;
  return historyLast.isAfter(stamped) ? historyLast : stamped;
}

int nextBestStreak({required int bestStreak, required int streak}) =>
    streak > bestStreak ? streak : bestStreak;

bool streakGraceExpired({
  required DateTime lastDay,
  required DateTime today,
  required int maxMissedDays,
}) {
  return dayDiff(today, lastDay) > maxMissedDays + 1;
}

String dayId(DateTime now) {
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return '${now.year}-$mm-$dd';
}
