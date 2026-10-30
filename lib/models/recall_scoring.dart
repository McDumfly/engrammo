library;

import '../l10n/app_localizations.dart';
import 'item_banks.dart' show StoryIdeaUnit, storyUnitsFor;
import 'meta_task.dart';

class RecallScore {
  final double proportion;
  final bool exact;
  final String detail;
  const RecallScore({
    required this.proportion,
    required this.exact,
    this.detail = '',
  });
}

String normalizeAnswer(String raw) {
  var s = raw.toLowerCase().trim();
  const folds = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ő': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'ű': 'u', 'û': 'u',
    'ý': 'y', 'ÿ': 'y', 'ç': 'c', 'ñ': 'n', 'ß': 'ss',
    'æ': 'ae', 'œ': 'oe',
  };
  folds.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r"[^a-z0-9 ]"), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      if (ins < best) best = ins;
      final sub = prev[j - 1] + cost;
      if (sub < best) best = sub;
      cur[j] = best;
    }
    prev = cur;
  }
  return prev[b.length];
}

bool fuzzyWordMatch(String expected, String got) {
  if (expected == got) return true;
  final d = levenshtein(expected, got);
  if (expected.length >= 9) return d <= 2;
  if (expected.length >= 5) return d <= 1;
  return false;
}

List<String> parseDigits(String response) =>
    [for (final m in RegExp(r'\d').allMatches(response)) m.group(0)!];

List<int> parseCells(String response) {
  final out = <int>[];
  for (final part in response.split(RegExp(r'[^0-9]+'))) {
    if (part.isEmpty) continue;
    final v = int.tryParse(part);
    if (part.length > 1 && v != null && v > 8) {
      for (final ch in part.split('')) {
        out.add(int.parse(ch));
      }
    } else if (v != null && v >= 0 && v <= 8) {
      out.add(v);
    }
  }
  return out;
}

const _stopwords = {
  'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'at', 'with',
  'from', 'for', 'was', 'were', 'is', 'are', 'it', 'its', 'that', 'this',
  'az', 'es', 'meg', 'egy', 'nem', 'hogy', 'ha', 'de', 's', 'volt',
  'van', 'ezt', 'azt', 'mar',
};

List<String> contentWords(String text) => [
      for (final w in normalizeAnswer(text).split(' '))
        if (w.isNotEmpty && !_stopwords.contains(w)) w,
    ];

RecallScore scoreDigitSpan(List<String> expected, String response) {
  final got = parseDigits(response);
  if (expected.isEmpty) {
    return const RecallScore(proportion: 0, exact: false);
  }
  var hits = 0;
  for (var i = 0; i < expected.length; i++) {
    if (i < got.length && got[i] == expected[i]) hits++;
  }
  final exact = hits == expected.length && got.length == expected.length;
  return RecallScore(
    proportion: hits / expected.length,
    exact: exact,
    detail: tr('score_digits', {'hits': hits, 'total': expected.length}),
  );
}

RecallScore scoreSingleToken(String expected, String response) {
  final exp = normalizeAnswer(expected);
  final got = normalizeAnswer(response);
  if (exp.isEmpty) return const RecallScore(proportion: 0, exact: false);
  if (got == exp) {
    return RecallScore(proportion: 1, exact: true, detail: tr('score_exact'));
  }
  final words = got.split(' ');
  if (words.contains(exp) || fuzzyWordMatch(exp, got)) {
    return RecallScore(
      proportion: 1,
      exact: false,
      detail: tr('score_extra'),
    );
  }
  for (final w in words) {
    if (fuzzyWordMatch(exp, w)) {
      return RecallScore(
        proportion: 0.75,
        exact: false,
        detail: tr('score_close'),
      );
    }
  }
  return RecallScore(proportion: 0, exact: false, detail: tr('score_miss'));
}

RecallScore scorePhraseRecall(String expected, String response) {
  final exp = contentWords(expected);
  if (exp.isEmpty) return const RecallScore(proportion: 0, exact: false);
  final got = contentWords(response).toSet();
  var hits = 0;
  for (final w in exp.toSet()) {
    if (got.contains(w) || got.any((g) => fuzzyWordMatch(w, g))) hits++;
  }
  final exact = normalizeAnswer(response) == normalizeAnswer(expected);
  return RecallScore(
    proportion: hits / exp.toSet().length,
    exact: exact,
    detail: tr('score_keywords', {'hits': hits, 'total': exp.toSet().length}),
  );
}

RecallScore scoreStoryRecall(List<StoryIdeaUnit> units, String response) {
  if (units.isEmpty) return const RecallScore(proportion: 0, exact: false);
  final got = contentWords(response).toSet();
  final flat = normalizeAnswer(response);
  var hits = 0;
  for (final u in units) {
    var found = false;
    for (final rawKey in u.keywords) {
      final key = normalizeAnswer(rawKey);
      if (key.isEmpty) continue;
      if (!key.contains(' ')) {
        if (got.contains(key) || got.any((g) => fuzzyWordMatch(key, g))) {
          found = true;
        }
      } else if (flat.contains(key)) {
        found = true;
      }
      if (found) break;
    }
    if (found) hits++;
  }
  return RecallScore(
    proportion: hits / units.length,
    exact: hits == units.length,
    detail: tr('score_units', {'hits': hits, 'total': units.length}),
  );
}

RecallScore scoreOrderedCells(List<int> expected, List<int> tapped) {
  if (expected.isEmpty) {
    return const RecallScore(proportion: 0, exact: false);
  }
  var hits = 0;
  for (var i = 0; i < expected.length; i++) {
    if (i < tapped.length && tapped[i] == expected[i]) hits++;
  }
  final exact =
      hits == expected.length && tapped.length == expected.length;
  return RecallScore(
    proportion: hits / expected.length,
    exact: exact,
    detail: tr('score_taps', {'hits': hits, 'total': expected.length}),
  );
}

RecallScore scoreCellSet(List<int> expected, String response) {
  if (expected.isEmpty) {
    return const RecallScore(proportion: 0, exact: false);
  }
  final exp = expected.toSet();
  final got = parseCells(response).toSet();
  final hits = got.intersection(exp).length;
  final falseAlarms = got.difference(exp).length;
  final exact = hits == exp.length && falseAlarms == 0;
  final prop = ((hits - falseAlarms) / exp.length).clamp(0.0, 1.0);
  return RecallScore(
    proportion: prop,
    exact: exact,
    detail: tr('score_cells', {
      'hits': hits,
      'total': exp.length,
      'extra': falseAlarms,
    }),
  );
}

String _answerKey(MetaTask task) {
  if (task.correct < 0 || task.correct >= task.options.length) return '';
  return task.options[task.correct];
}

RecallScore scoreTaskRecall(MetaTask task, String response) {
  switch (task.paradigm) {
    case 'backward-span':
      return scoreDigitSpan(parseDigits(_answerKey(task)), response);
    case 'chunk-span':
      final exp = _answerKey(task).replaceAll(RegExp(r'\D'), '').split('');
      return scoreDigitSpan(exp, response);
    case 'iconic-probe':
    case 'echoic-probe':
      return scoreSingleToken(_answerKey(task), response);
    case 'brown-peterson':
      final exp = normalizeAnswer(_answerKey(task));
      final got = normalizeAnswer(response);
      if (exp.isEmpty) {
        return const RecallScore(proportion: 0, exact: false);
      }
      var hits = 0;
      for (var i = 0; i < exp.length; i++) {
        if (i < got.length && got[i] == exp[i]) hits++;
      }
      return RecallScore(
        proportion: hits / exp.length,
        exact: got == exp,
        detail: tr('score_letters', {'hits': hits, 'total': exp.length}),
      );
    case 'pattern-span':
      return scoreCellSet(
        [for (final e in task.items) int.tryParse(e.trim()) ?? -1]
            .where((c) => c >= 0 && c <= 8)
            .toList(),
        response,
      );
    case 'story-recall':
      final units = task.items.isEmpty
          ? const <StoryIdeaUnit>[]
          : storyUnitsFor(task.items.first);
      if (units.isNotEmpty) return scoreStoryRecall(units, response);
      return scorePhraseRecall(_answerKey(task), response);
    case 'loci-drill':
    case 'picture-recall':
    case 'paired-associate':
    case 'face-name':
    case 'keyword-pair':
    case 'prospective-cue':
    case 'poem-chunk':
    case 'day-replay':
    case 'category-exemplar':
      final key = _answerKey(task);
      final single = scoreSingleToken(key, response);
      if (single.proportion > 0) return single;
      return scorePhraseRecall(key, response);
    default:
      return scorePhraseRecall(_answerKey(task), response);
  }
}
