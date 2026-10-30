import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'memory_store.dart';

/// Hard ceiling for every memory-kind score.
const growthMaxScore = 100;

/// Largest raw gain a single practice event may request.
const growthMaxBasePerEvent = 3;

/// Largest total gain one kind may collect per calendar day.
const growthMaxPerDayPerKind = 5;

/// Diminishing-returns gain for one score.
///
/// [score] is the current 0-100 value, [base] the raw 0-3 event reward.
/// Low scores keep the full base, high scores shrink toward +1, and a
/// maxed-out score gains nothing. Pure: no storage access.
int growthDelta({required int score, required int base}) {
  final clampedScore = score.clamp(0, growthMaxScore);
  final clampedBase = base.clamp(0, growthMaxBasePerEvent);
  if (clampedBase <= 0 || clampedScore >= growthMaxScore) return 0;
  final scaled =
      (clampedBase * (growthMaxScore - clampedScore) / growthMaxScore).round();
  final delta = scaled.clamp(1, clampedBase);
  final room = growthMaxScore - clampedScore;
  return delta > room ? room : delta;
}

/// Pure practice gain: returns a copy of [scores] with the kind at [kind]
/// grown by [base] (diminishing near 100, clamped 0-100).
///
/// Out-of-range [kind] returns an unchanged copy; the input is never mutated.
List<int> applyPracticeGain(List<int> scores, int kind, int base) {
  final next = List<int>.of(scores);
  if (kind < 0 || kind >= next.length) return next;
  final current = next[kind].clamp(0, growthMaxScore);
  next[kind] =
      (current + growthDelta(score: current, base: base)).clamp(
        0,
        growthMaxScore,
      );
  return next;
}

String _growthDayString(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// Applies one practice gain to the stored scores.
///
/// Loads via [MemoryStore.loadScores], enforces the +5/kind daily cap, and
/// persists via [MemoryStore.saveScoresWithoutNotify] plus the [MemoryStore]
/// change callback — never [MemoryStore.saveScores], so the assessment-runs
/// counter stays untouched. Returns the stored scores afterwards, or null
/// when no assessment exists yet.
Future<List<int>?> applyGrowth({
  required int kind,
  required int base,
  DateTime? now,
}) async {
  final scores = await MemoryStore.loadScores();
  if (scores == null || scores.isEmpty) return null;
  if (kind < 0 || kind >= scores.length) return scores;
  if (base <= 0) return scores;

  final day = _growthDayString(now ?? DateTime.now());
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(MemoryGrowthDay.key) ?? const <String>[];
  final used = <int, int>{};
  if (raw.isNotEmpty && raw.first == day) {
    for (final entry in raw.skip(1)) {
      final i = entry.indexOf('=');
      if (i <= 0) continue;
      final k = int.tryParse(entry.substring(0, i));
      final v = int.tryParse(entry.substring(i + 1));
      if (k != null && v != null && v > 0) used[k] = v;
    }
  }

  final current = scores[kind].clamp(0, growthMaxScore);
  final delta = growthDelta(score: current, base: base);
  final remaining = growthMaxPerDayPerKind - (used[kind] ?? 0);
  final granted = delta > remaining ? remaining : delta;
  if (granted <= 0) return scores;

  final next = List<int>.of(scores);
  next[kind] = (current + granted).clamp(0, growthMaxScore);
  used[kind] = (used[kind] ?? 0) + granted;
  await prefs.setStringList(MemoryGrowthDay.key, [
    day,
    for (final e in used.entries) '${e.key}=${e.value}',
  ]);
  await MemoryStore.saveScoresWithoutNotify(next);
  final cb = MemoryStore.onChanged;
  if (cb != null) unawaited(cb());
  return next;
}

/// Storage key holder for the per-day growth ledger.
abstract final class MemoryGrowthDay {
  static const key = 'growth_day_v1';
}
