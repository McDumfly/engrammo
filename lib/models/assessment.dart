library;

import '../l10n/app_localizations.dart';

const assessmentProbeCount = 13;

int scoreForPair({required bool easyCorrect, required bool hardCorrect}) {
  return pointsForProportion(
        proportion: easyCorrect ? 1 : 0,
        hard: false,
      ) +
      pointsForProportion(proportion: hardCorrect ? 1 : 0, hard: true);
}

const spatialProbeBudgets = [20, 30, 50];

const corsiProbeSequences = [
  [
    [0, 8, 4],
    [2, 6, 4],
    [4, 1, 7],
    [7, 3, 5],
  ],
  [
    [0, 4, 2, 8, 6],
    [2, 4, 6, 0, 8],
    [8, 1, 6, 3, 0],
    [6, 7, 0, 4, 2],
  ],
  [
    [1, 5, 0, 2, 7, 4],
    [3, 7, 2, 6, 1, 0],
    [5, 2, 4, 0, 7, 8],
    [8, 1, 6, 2, 5, 0],
  ],
];

/// Blind digit-span direction: whether the easy / hard working-memory probe
/// asks for REVERSED order in a given form. The easy probe reveals nothing
/// about the hard one — P(hard reversed | easy reversed) ==
/// P(hard reversed | easy forward) == 1/2 — so pre-reversing the hard
/// sequence at study time is a coin flip, not a cheat.
const backEasyReversedByForm = [true, false, false, true];
const backHardReversedByForm = [false, true, false, true];

bool backEasyReversed(int form) => backEasyReversedByForm[form % 4];

bool backHardReversed(int form) => backHardReversedByForm[form % 4];

/// 0-based cue slot(s) for the sensory partial-report probes. The easy probe
/// shows 3 digits and cues 1 afterwards; the hard probe shows 6 digits and
/// cues 2. Slots vary by form so retakes cannot pre-select one position.
const iconicEasyCueByForm = [1, 0, 2, 1];

const iconicHardCuesByForm = [
  [1, 4],
  [2, 5],
  [0, 3],
  [1, 3],
];

String ordinal(int n) {
  if (AppLocalizations.isHungarian) return '$n.';
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

int pointsForBudget({required double proportion, required int max}) {
  return (max * proportion.clamp(0.0, 1.0)).round();
}

int pointsForProportion({required double proportion, required bool hard}) {
  return pointsForBudget(proportion: proportion, max: hard ? 60 : 40);
}

int? dominantKind(List<int>? scores) {
  if (scores == null || scores.isEmpty) return null;
  var best = 0;
  for (var i = 1; i < scores.length; i++) {
    if (scores[i] > scores[best]) best = i;
  }
  return best;
}

class DominantResult {
  final int? kind;

  final List<int> tied;

  final String rationale;

  const DominantResult({
    required this.kind,
    required this.tied,
    required this.rationale,
  });
}

DominantResult resolveDominant({
  required List<int>? scores,
  List<int>? hardHits,
  List<int>? latenciesMs,
  int? interviewKind,
}) {
  if (scores == null || scores.isEmpty) {
    return DominantResult(
      kind: null,
      tied: const [],
      rationale: tr('assess_dom_none'),
    );
  }
  if (scoresAreBlank(scores)) {
    return DominantResult(
      kind: null,
      tied: const [],
      rationale: tr('assess_dom_blank'),
    );
  }
  final top = scores.reduce((a, b) => a > b ? a : b);
  var tied = [
    for (var i = 0; i < scores.length; i++)
      if (scores[i] == top) i,
  ];
  if (tied.length == 1) {
    return DominantResult(
      kind: tied.first,
      tied: tied,
      rationale: tr('assess_dom_clear'),
    );
  }
  if (hardHits != null && hardHits.length == scores.length) {
    final bestHard = tied.map((i) => hardHits[i]).reduce((a, b) => a > b ? a : b);
    final narrowed = tied.where((i) => hardHits[i] == bestHard).toList();
    if (narrowed.length == 1) {
      return DominantResult(
        kind: narrowed.first,
        tied: tied,
        rationale: tr('assess_dom_hard'),
      );
    }
    tied = narrowed;
  }
  if (latenciesMs != null && latenciesMs.length == scores.length) {
    final measured = tied.where((i) => latenciesMs[i] > 0).toList();
    if (measured.isNotEmpty) {
      final fastest = measured
          .map((i) => latenciesMs[i])
          .reduce((a, b) => a < b ? a : b);
      final narrowed = measured
          .where((i) => latenciesMs[i] == fastest)
          .toList();
      if (narrowed.length == 1) {
        return DominantResult(
          kind: narrowed.first,
          tied: tied,
          rationale: tr('assess_dom_fast'),
        );
      }
      tied = narrowed;
    }
  }
  if (interviewKind != null && tied.contains(interviewKind)) {
    return DominantResult(
      kind: interviewKind,
      tied: tied,
      rationale: tr('assess_dom_interview'),
    );
  }
  return DominantResult(
    kind: null,
    tied: tied,
    rationale: tr('assess_dom_balanced', {'n': tied.length}),
  );
}

class AssessmentColorChip {
  final String name;
  final int argb;
  const AssessmentColorChip(this.name, this.argb);
}

const assessmentColorChips = [
  AssessmentColorChip('Blue', 0xFF2F7CF6),
  AssessmentColorChip('Green', 0xFF22B07D),
  AssessmentColorChip('Orange', 0xFFFF9500),
  AssessmentColorChip('Red', 0xFFFF5A5A),
  AssessmentColorChip('Purple', 0xFF8B5CF6),
  AssessmentColorChip('Yellow', 0xFFEAB308),
];

AssessmentColorChip chipNotAmong(List<AssessmentColorChip> shown) {
  final names = shown.map((c) => c.name).toSet();
  return assessmentColorChips.firstWhere(
    (c) => !names.contains(c.name),
    orElse: () => assessmentColorChips.first,
  );
}

bool scoresAreBlank(List<int>? scores) {
  if (scores == null || scores.isEmpty) return true;
  return scores.every((s) => s <= 0);
}

int levelForScores(List<int> scores) {
  if (scores.isEmpty) return 1;
  final avg = scores.reduce((a, b) => a + b) ~/ scores.length;
  return (avg.clamp(0, 100) ~/ 10) + 1;
}

int starsForLesson({required bool correct, required Duration elapsed}) {
  if (!correct) return 1;
  if (elapsed < const Duration(seconds: 15)) return 3;
  return 2;
}
