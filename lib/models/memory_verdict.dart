library;

import 'dart:convert';

import '../l10n/app_localizations.dart';
import 'interview.dart' show interviewQuestions;

class InterviewAnswer {
  final String questionId;
  final int? picked;
  final String custom;
  const InterviewAnswer({required this.questionId, this.picked, this.custom = ''});
}

class MemoryVerdict {
  final int kind;

  final double confidence;

  final String rationale;

  final bool fallback;

  const MemoryVerdict({
    required this.kind,
    required this.confidence,
    required this.rationale,
    this.fallback = false,
  });
}

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
    if (name.startsWith('working')) return 1;
  }
  return null;
}

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
          ? tr('verdict_default')
          : (data['rationale'] as String).trim(),
    );
  } catch (_) {
    return null;
  }
}

const _keywords = <int, List<String>>{
  0: ['sound', 'hear', 'listen', 'voice', 'music', 'rhythm', 'audio', 'noise', 'song', 'aloud', 'hang', 'zene', 'hall', 'zaj', 'dal', 'hangosan', 'hangja'],
  1: ['number', 'digit', 'calculat', 'repeat', 'rehears', 'phone', 'count', 'steps', 'szam', 'szám', 'számjegy', 'számol', 'ismétel', 'telefon', 'lépés'],
  2: ['map', 'direction', 'navigat', 'route', 'house', 'room', 'walk', 'place', 'space', 'lost', 'left', 'right', 'térkép', 'irány', 'útvonal', 'ház', 'szoba', 'séta', 'hely', 'tér', 'elvé', 'bal', 'jobb'],
  3: ['picture', 'image', 'color', 'colour', 'see', 'face', 'diagram', 'visual', 'sight', 'look', 'kép', 'szín', 'lát', 'arc', 'ábra', 'vizuális', 'néz'],
  4: ['story', 'event', 'yesterday', 'day', 'remember', 'diary', 'experience', 'happen', 'movie', 'scene', 'történet', 'esemény', 'tegnap', 'nap', 'emléksz', 'napló', 'élmény', 'történt', 'film', 'jelenet'],
  5: ['meaning', 'word', 'fact', 'concept', 'categor', 'name', 'know', 'list', 'logic', 'jelentés', 'szó', 'tény', 'fogalom', 'kateg', 'név', 'tud', 'lista', 'logika'],
};

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
  final blankScores =
      scores.isEmpty || scores.every((s) => s <= 0);
  if (blankScores && answered == 0) {
    return MemoryVerdict(
      kind: 0,
      confidence: 0.5,
      rationale: tr('verdict_blank'),
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
  final kindName = tr('verdict_kind_$best');
  return MemoryVerdict(
    kind: best,
    confidence: confidence,
    rationale: answered == 1
        ? tr('verdict_local_one', {'kind': kindName})
        : tr('verdict_local_many', {'n': answered, 'kind': kindName}),
    fallback: true,
  );
}
