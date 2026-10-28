/// Verdict model for the AI interview + the offline fallback.
///
/// The interview ends in one verdict: the dominant memory kind with a
/// confidence and a human-readable rationale. Online, Muse Spark
/// writes the verdict from test scores + interview answers
/// ([MetaAIService.analyzeMemoryType]). Offline — or when the API
/// call fails — [heuristicVerdict] computes the same shape
/// deterministically from the same inputs, so the flow never blocks.
library;

import 'dart:convert';

import 'interview.dart' show interviewQuestions;

/// One answered interview question: the picked option index (null =
/// skipped the choices) plus optional free custom text.
class InterviewAnswer {
  final String questionId;
  final int? picked;
  final String custom;
  const InterviewAnswer({required this.questionId, this.picked, this.custom = ''});
}

/// The final dominant-type verdict (AI-written or heuristic).
class MemoryVerdict {
  /// Dominant kind index (0-5, same order as `memoryKinds`).
  final int kind;

  /// 0-1 confidence in the verdict.
  final double confidence;

  /// One or two sentences explaining the call, shown to the user.
  final String rationale;

  /// True when computed locally (no AI call succeeded).
  final bool fallback;

  const MemoryVerdict({
    required this.kind,
    required this.confidence,
    required this.rationale,
    this.fallback = false,
  });
}

/// Kind names the AI may return instead of an index.
const verdictKindNames = [
  'sensory',
  'working',
  'spatial',
  'visual',
  'episodic',
  'semantic',
];

int? _kindFromDynamic(dynamic raw) {
  if (raw is num) {
    final k = raw.toInt();
    return (k >= 0 && k < 6) ? k : null;
  }
  if (raw is String) {
    final name = raw.trim().toLowerCase();
    for (var i = 0; i < verdictKindNames.length; i++) {
      if (name == verdictKindNames[i] || name.startsWith(verdictKindNames[i])) {
        return i;
      }
    }
    // "Working memory" etc. also match by prefix ("working").
    if (name.startsWith('working')) return 1;
  }
  return null;
}

/// Parses the AI verdict JSON: {"dominant": 2 | "Spatial",
/// "confidence": 0..1, "rationale": "..."}.
///
/// Returns null when the payload is unusable — the caller then falls
/// back to [heuristicVerdict].
MemoryVerdict? parseVerdictContent(String content) {
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
    final kind = _kindFromDynamic(data['dominant']);
    if (kind == null) return null;
    final conf = (data['confidence'] as num?)?.toDouble() ?? 0.6;
    return MemoryVerdict(
      kind: kind,
      confidence: conf.clamp(0.0, 1.0),
      rationale: (data['rationale'] as String?)?.trim().isEmpty ?? true
          ? 'AI verdict from your test scores and interview answers.'
          : (data['rationale'] as String).trim(),
    );
  } catch (_) {
    return null;
  }
}

/// Custom-text keyword scan per kind (offline fallback only).
const _keywords = <int, List<String>>{
  0: ['sound', 'hear', 'listen', 'voice', 'music', 'rhythm', 'audio', 'noise', 'song', 'aloud'],
  1: ['number', 'digit', 'calculat', 'repeat', 'rehears', 'phone', 'count', 'steps'],
  2: ['map', 'direction', 'navigat', 'route', 'house', 'room', 'walk', 'place', 'space', 'lost', 'left', 'right'],
  3: ['picture', 'image', 'color', 'colour', 'see', 'face', 'diagram', 'visual', 'sight', 'look'],
  4: ['story', 'event', 'yesterday', 'day', 'remember', 'diary', 'experience', 'happen', 'movie', 'scene'],
  5: ['meaning', 'word', 'fact', 'concept', 'categor', 'name', 'know', 'list', 'logic'],
};

/// Deterministic offline verdict from the same inputs the AI sees.
///
/// Totals per kind = test score (scaled to 0-5) + picked-option
/// weights + one point per kind per custom answer that mentions its
/// keywords. Ties break by hard-item hits, then by lowest index —
/// the same ladder order as [resolveDominant] in `assessment.dart`,
/// so online and offline verdicts stay consistent.
MemoryVerdict heuristicVerdict({
  required List<int> scores,
  required List<InterviewAnswer> answers,
  List<int>? hardHits,
}) {
  final byId = {for (final q in interviewQuestions) q.id: q};
  final totals = List<double>.filled(6, 0);
  for (var i = 0; i < scores.length && i < 6; i++) {
    totals[i] += scores[i] / 20.0;
  }
  var answered = 0;
  for (final a in answers) {
    final q = byId[a.questionId];
    if (q == null) continue;
    if (a.picked != null && a.picked! >= 0 && a.picked! < q.options.length) {
      answered++;
      q.options[a.picked!].weights.forEach((kind, w) {
        if (kind >= 0 && kind < 6) totals[kind] += w;
      });
    }
    final text = a.custom.trim().toLowerCase();
    if (text.isNotEmpty) {
      answered++;
      _keywords.forEach((kind, words) {
        if (words.any(text.contains)) totals[kind] += 1;
      });
    }
  }
  // Blank guard: no measured scores and no answered content means
  // nothing was measured — never crown a fake winner (kind 0).
  final blankScores =
      scores.isEmpty || scores.every((s) => s <= 0);
  if (blankScores && answered == 0) {
    return const MemoryVerdict(
      kind: 0,
      confidence: 0.5,
      rationale:
          'Nothing measurable yet — finish the assessment to get a verdict.',
      fallback: true,
    );
  }
  var best = 0;
  for (var i = 1; i < 6; i++) {
    if (totals[i] > totals[best]) {
      best = i;
    } else if (totals[i] == totals[best] &&
        hardHits != null &&
        hardHits.length == 6 &&
        hardHits[i] > hardHits[best]) {
      best = i;
    }
  }
  final sorted = List.of(totals)..sort();
  final margin = sorted[5] - sorted[4];
  final confidence = (0.5 + margin / 10.0).clamp(0.5, 0.9);
  return MemoryVerdict(
    kind: best,
    confidence: confidence,
    rationale:
        'Local analysis of your $answered interview answer${answered == 1 ? '' : 's'} '
        'combined with test scores points to ${verdictKindNames[best]} memory.',
    fallback: true,
  );
}
