library;

import 'dart:convert';

import '../l10n/app_localizations.dart';
import 'assessment.dart' show resolveDominant, scoresAreBlank;
import 'memory_verdict.dart' show verdictKindNames;

class StudyRecommendation {
  final int track;

  final String rationale;

  final bool fallback;

  const StudyRecommendation({
    required this.track,
    required this.rationale,
    this.fallback = false,
  });
}

int? _trackFromDynamic(dynamic raw) {
  if (raw is num) {
    final t = raw.toInt();
    return (t >= 0 && t < 6) ? t : null;
  }
  if (raw is String) {
    final name = raw.trim().toLowerCase();
    for (var i = 0; i < verdictKindNames.length; i++) {
      if (name == verdictKindNames[i] || name.startsWith(verdictKindNames[i])) {
        return i;
      }
    }
    if (name.startsWith('working')) return 1;
  }
  return null;
}

StudyRecommendation? parseStudyRecommendationContent(String content) {
  try {
    var text = content.trim();
    if (text.startsWith('```')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      text = text.substring(start, end + 1);
    }
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic>) return null;
    final track = _trackFromDynamic(data['track']);
    if (track == null) return null;
    return StudyRecommendation(
      track: track,
      rationale: (data['rationale'] as String?)?.trim().isEmpty ?? true
          ? tr('study_default')
          : (data['rationale'] as String).trim(),
    );
  } catch (_) {
    return null;
  }
}

StudyRecommendation heuristicStudyRecommendation({
  required List<int>? scores,
  List<int>? hardHits,
  List<int>? latenciesMs,
  int? interviewKind,
}) {
  final validInterview =
      interviewKind != null && interviewKind >= 0 && interviewKind < 6
      ? interviewKind
      : null;
  if (scores == null || scores.isEmpty || scoresAreBlank(scores)) {
    if (validInterview != null) {
      return StudyRecommendation(
        track: validInterview,
        rationale: tr('study_no_signal', {
          'kind': tr('verdict_kind_$validInterview'),
        }),
        fallback: true,
      );
    }
    return StudyRecommendation(
      track: 0,
      rationale: tr('study_blank'),
      fallback: true,
    );
  }
  final d = resolveDominant(
    scores: scores,
    hardHits: hardHits,
    latenciesMs: latenciesMs,
    interviewKind: validInterview,
  );
  if (d.kind != null) {
    var weakest = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] < scores[weakest]) weakest = i;
    }
    return StudyRecommendation(
      track: d.kind!,
      rationale: tr('study_strongest', {
        'kind': tr('verdict_kind_${d.kind!}'),
        'weak': tr('verdict_kind_$weakest'),
      }),
      fallback: true,
    );
  }
  final tied = d.tied.isEmpty ? [0] : d.tied;
  final names = [for (final i in tied) tr('verdict_kind_$i')].join(', ');
  return StudyRecommendation(
    track: tied.first,
    rationale: tr('study_balanced', {
      'names': names,
      'kind': tr('verdict_kind_${tied.first}'),
    }),
    fallback: true,
  );
}
