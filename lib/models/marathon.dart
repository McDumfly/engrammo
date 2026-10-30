library;

import '../l10n/app_localizations.dart';
import 'curriculum.dart' show chapters, chaptersForTrack;

const practiceDepths = 11;

const sessionsPerLessonFull = 1 + practiceDepths;

const labDoseMinutesPerTrack = 1200;

const stretchDoseMinutesPerTrack = 4800;

const minutesPerSession = 5;

const maxStoredReps = 99;

int lessonsInTrack(int track) {
  final order = chaptersForTrack(track.clamp(0, 5));
  var total = 0;
  for (final c in order) {
    if (c < 0 || c >= chapters.length) continue;
    for (final s in chapters[c].sections) {
      total += s.lessons.length;
    }
  }
  return total;
}

int sessionsToFinishTrack(int track) =>
    lessonsInTrack(track) * sessionsPerLessonFull;

int estimatedMinutesToFinishTrack(int track) =>
    sessionsToFinishTrack(track) * minutesPerSession;

int depthForReps(int reps) => reps.clamp(0, practiceDepths);

int depthForNextSession({required int reps, required int stars}) {
  final effective = reps > 0 ? reps : (stars > 0 ? 1 : 0);
  return depthForReps(effective);
}

int roundsForDepth(int baseRounds, int depth) {
  final d = depth.clamp(0, practiceDepths);
  final extra = (d >= 3 ? 1 : 0) + (d >= 7 ? 1 : 0);
  return (baseRounds + extra).clamp(2, 6);
}

int lagForDepth(int baseLag, int depth) {
  final d = depth.clamp(0, practiceDepths);
  final extra = (d >= 2 ? 1 : 0) + (d >= 6 ? 1 : 0);
  return (baseLag + extra).clamp(0, 2);
}

int difficultyBoostForDepth(int depth) {
  final d = depth.clamp(0, practiceDepths);
  if (d >= 8) return 2;
  if (d >= 4) return 1;
  return 0;
}

String variantSeedFor(int chapter, int section, int lesson, int depth) =>
    '$chapter-$section-$lesson-d${depth.clamp(0, practiceDepths)}';

String marathonLessonKey(int chapter, int section, int lesson) =>
    '$chapter-$section-$lesson';

String _tierKeyForAverage(double average) {
  if (average >= 9) return 'mar_tier_durable';
  if (average >= 5.5) return 'mar_tier_deep';
  if (average >= 3.5) return 'mar_tier_solid';
  if (average >= 1) return 'mar_tier_building';
  return 'mar_tier_foundation';
}

String tierForAverageDepth(double average) {
  if (average >= 9) return 'Durable';
  if (average >= 5.5) return 'Deep';
  if (average >= 3.5) return 'Solid';
  if (average >= 1) return 'Building';
  return 'Foundation';
}

String tierForAverageDepthIn(String locale, double average) =>
    trFor(locale, _tierKeyForAverage(average));

double trackDepthAverage({
  required Map<String, int> reps,
  required Map<String, int> progress,
  required int track,
}) {
  final order = chaptersForTrack(track.clamp(0, 5));
  var sum = 0;
  var total = 0;
  for (final c in order) {
    if (c < 0 || c >= chapters.length) continue;
    final chapter = chapters[c];
    for (var s = 0; s < chapter.sections.length; s++) {
      for (var l = 0; l < chapter.sections[s].lessons.length; l++) {
        total++;
        final key = marathonLessonKey(c, s, l);
        final r = reps[key] ?? 0;
        final effective = r > 0 ? r : ((progress[key] ?? 0) > 0 ? 1 : 0);
        sum += depthForReps(effective);
      }
    }
  }
  if (total == 0) return 0;
  return sum / total;
}

int sessionsDoneOnTrack({
  required Map<String, int> reps,
  required Map<String, int> progress,
  required int track,
}) {
  final order = chaptersForTrack(track.clamp(0, 5));
  var done = 0;
  for (final c in order) {
    if (c < 0 || c >= chapters.length) continue;
    final chapter = chapters[c];
    for (var s = 0; s < chapter.sections.length; s++) {
      for (var l = 0; l < chapter.sections[s].lessons.length; l++) {
        final key = marathonLessonKey(c, s, l);
        final r = reps[key] ?? 0;
        final effective = r > 0 ? r : ((progress[key] ?? 0) > 0 ? 1 : 0);
        done += effective.clamp(0, sessionsPerLessonFull);
      }
    }
  }
  return done;
}

const reviewGapDays = <int>[1, 2, 4, 7, 11, 15, 20, 26, 33, 41, 50, 60];

int daysUntilReviewDue({
  required DateTime? lastDone,
  required int depth,
  required DateTime now,
}) {
  if (lastDone == null) return 0;
  final gap = reviewGapDays[depth.clamp(0, reviewGapDays.length - 1)];
  final due = DateTime(
    lastDone.year,
    lastDone.month,
    lastDone.day,
  ).add(Duration(days: gap));
  final today = DateTime(now.year, now.month, now.day);
  return due.difference(today).inDays;
}

String depthChipLabel(int depth) {
  final d = depth.clamp(0, practiceDepths);
  if (d <= 0) return 'First pass — learn the move';
  return 'Practice round $d of $practiceDepths — harder set, fresh items';
}

String depthChipLabelIn(String locale, int depth) {
  final d = depth.clamp(0, practiceDepths);
  if (d <= 0) return trFor(locale, 'mar_depth_first');
  return trFor(locale, 'mar_depth_round', {
    'd': d,
    'total': practiceDepths,
  });
}

String trackProgramLine(int track) {
  final sessions = sessionsToFinishTrack(track);
  final hours = estimatedMinutesToFinishTrack(track) ~/ 60;
  return 'Full program: about $sessions short sessions (~$hours hours of guided practice) across many months of spaced review, plus your own material. '
      'Practice rounds unlock when due — the lab protocol behind this dose used about 20 hours over 6 weeks on one technique (Dresler et al. 2017).';
}

String trackProgramLineIn(String locale, int track) {
  final sessions = sessionsToFinishTrack(track);
  final hours = estimatedMinutesToFinishTrack(track) ~/ 60;
  return trFor(locale, 'mar_program_line', {
    'sessions': sessions,
    'hours': hours,
  });
}

bool practiceRoundLocked({
  required DateTime? lastDone,
  required int depth,
  required int stars,
  required DateTime now,
}) {
  if (stars <= 0 || depth <= 0) return false;
  return daysUntilReviewDue(lastDone: lastDone, depth: depth, now: now) > 0;
}

String reviewStatusLabel({
  required DateTime? lastDone,
  required int depth,
  required DateTime now,
}) {
  final left = daysUntilReviewDue(
    lastDone: lastDone,
    depth: depth,
    now: now,
  );
  if (left <= 0) return 'Due for review';
  if (left == 1) return 'Review tomorrow';
  return 'Review in $left days';
}

String reviewStatusLabelIn(
  String locale, {
  required DateTime? lastDone,
  required int depth,
  required DateTime now,
}) {
  final left = daysUntilReviewDue(
    lastDone: lastDone,
    depth: depth,
    now: now,
  );
  if (left <= 0) return trFor(locale, 'mar_due');
  if (left == 1) return trFor(locale, 'mar_tomorrow');
  return trFor(locale, 'mar_in_days', {'n': left});
}

String reviewLockedMessage({required int depth, required int daysLeft}) {
  final wait = daysLeft <= 1 ? 'tomorrow' : 'in $daysLeft days';
  return 'Practice round $depth of $practiceDepths unlocks $wait — spaced gaps protect the memory. Try another lesson or track.';
}

String reviewLockedMessageIn(
  String locale, {
  required int depth,
  required int daysLeft,
}) {
  final wait = daysLeft <= 1
      ? trFor(locale, 'mar_wait_tomorrow')
      : trFor(locale, 'mar_wait_days', {'n': daysLeft});
  return trFor(locale, 'mar_locked', {
    'depth': depth,
    'total': practiceDepths,
    'wait': wait,
  });
}

String nextReviewLine({required int daysLeft}) {
  if (daysLeft <= 0) return 'Due for review — the next round is open.';
  if (daysLeft == 1) {
    return 'Next review tomorrow — spaced gaps protect the memory.';
  }
  return 'Next review in $daysLeft days — spaced gaps protect the memory.';
}

String nextReviewLineIn(String locale, {required int daysLeft}) {
  if (daysLeft <= 0) return trFor(locale, 'mar_due_open');
  if (daysLeft == 1) return trFor(locale, 'mar_next_tomorrow');
  return trFor(locale, 'mar_next_days', {'n': daysLeft});
}

String labDoseProgressLine(int minutes) {
  final hours = minutes / 60;
  final shown = hours >= 10
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  final lab = labDoseMinutesPerTrack ~/ 60;
  final stretch = stretchDoseMinutesPerTrack ~/ 60;
  if (minutes >= stretchDoseMinutesPerTrack) {
    return '$shown of $stretch+ hours practiced on this path — past the extended program line. Keep it with spaced review.';
  }
  if (minutes >= labDoseMinutesPerTrack) {
    return '$shown of $lab hours practiced on this path — lab-dose line reached. The extended program runs to $stretch hours.';
  }
  return '$shown of $lab hours practiced on this path — the lab protocol behind this dose used $lab hours over 6 weeks (Dresler et al. 2017).';
}

String labDoseProgressLineIn(String locale, int minutes) {
  final hours = minutes / 60;
  final shown = hours >= 10
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  final lab = labDoseMinutesPerTrack ~/ 60;
  final stretch = stretchDoseMinutesPerTrack ~/ 60;
  if (minutes >= stretchDoseMinutesPerTrack) {
    return trFor(locale, 'mar_dose_past', {
      'shown': shown,
      'stretch': stretch,
    });
  }
  if (minutes >= labDoseMinutesPerTrack) {
    return trFor(locale, 'mar_dose_lab', {
      'shown': shown,
      'lab': lab,
      'stretch': stretch,
    });
  }
  return trFor(locale, 'mar_dose_progress', {
    'shown': shown,
    'lab': lab,
    'stretch': stretch,
  });
}
