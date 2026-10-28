/// Pure scoring rules for the memory assessment and memory levels.
///
/// Extracted from the widgets so the rules are unit-testable and the
/// research rationale lives in one place (see `docs/RESEARCH.md`).
library;

/// Points for one assessment item pair of a single memory type.
///
/// Each of the 6 memory types is probed with 2 items: an easy one
/// (40 points) and a hard one (60 points). Two items per construct is
/// the smallest step above a single yes/no probe: with one item every
/// type scores either 100 or 20 and most users tie everywhere, so no
/// dominant type can be determined. Scores per type: 0 / 40 / 60 / 100.
int scoreForPair({required bool easyCorrect, required bool hardCorrect}) {
  var score = 0;
  if (easyCorrect) score += 40;
  if (hardCorrect) score += 60;
  return score;
}

/// Index of the dominant (strongest) memory type, or null when the
/// user never finished an assessment.
///
/// Ties resolve to the lowest index (documented, deterministic).
/// Callers must treat null as "no assessment yet" and show a
/// call-to-action instead of a fake "Sensory 0%" default.
///
/// Prefer [resolveDominant] for user-facing verdicts: it breaks ties
/// with harder evidence instead of index order.
int? dominantKind(List<int>? scores) {
  if (scores == null || scores.isEmpty) return null;
  var best = 0;
  for (var i = 1; i < scores.length; i++) {
    if (scores[i] > scores[best]) best = i;
  }
  return best;
}

/// Outcome of the research-backed tie-breaking ladder.
class DominantResult {
  /// Resolved winner, or null when the top is still tied (the UI must
  /// then show a "balanced profile" card, never a fake single winner)
  /// or when nothing was measured.
  final int? kind;

  /// All kinds sharing the top score (length 1 = clear winner).
  final List<int> tied;

  /// One-line human explanation shown on the result page.
  final String rationale;

  const DominantResult({
    required this.kind,
    required this.tied,
    required this.rationale,
  });
}

/// Resolves the dominant memory type through a tie-breaking ladder.
///
/// Why a ladder: with only two probes per type, easy items hit a
/// ceiling (everyone scores 100 on several types, see the screenshot
/// in the issue history). Psychometrics handles this with harder,
/// more discriminating evidence first — never with index order:
///
/// 1. Top score wins outright when unique.
/// 2. Hard-item hits narrow the tie (hard probes discriminate;
///    easy probes ceiling — the same logic as adaptive tests and
///    Wechsler discontinue rules, which trust hard items more).
/// 3. Faster median recall narrows it further (fluent retrieval is
///    the efficient one; cf. neural-efficiency findings).
/// 4. The AI interview verdict picks — but only among the tied top:
///    self-report breaks performance ties (multitrait-multimethod
///    logic, Campbell & Fiske 1959), it never overrides a clear
///    performance gap.
/// 5. Still tied → [DominantResult.kind] stays null and the UI shows
///    a balanced profile listing every tied strength. A low-stakes
///    screener cannot honestly resolve differences smaller than its
///    own measurement error, so it must not pretend to.
DominantResult resolveDominant({
  required List<int>? scores,
  List<int>? hardHits,
  List<int>? latenciesMs,
  int? interviewKind,
}) {
  if (scores == null || scores.isEmpty) {
    return const DominantResult(
      kind: null,
      tied: [],
      rationale: 'No assessment yet.',
    );
  }
  if (scoresAreBlank(scores)) {
    return const DominantResult(
      kind: null,
      tied: [],
      rationale: 'Nothing measurable — no winner crowned.',
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
      rationale: 'Clear winner on test scores.',
    );
  }
  // Ladder rung 2: hard-item hits discriminate better than easy ones.
  if (hardHits != null && hardHits.length == scores.length) {
    final bestHard = tied.map((i) => hardHits[i]).reduce((a, b) => a > b ? a : b);
    final narrowed = tied.where((i) => hardHits[i] == bestHard).toList();
    if (narrowed.length == 1) {
      return DominantResult(
        kind: narrowed.first,
        tied: tied,
        rationale:
            'Tie on scores — decided by hard-item performance, which '
            'discriminates better than easy items.',
      );
    }
    tied = narrowed;
  }
  // Ladder rung 3: faster recall among the tied top.
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
          rationale:
              'Tie on scores — decided by faster recall, the more '
              'fluent memory trace.',
        );
      }
      tied = narrowed;
    }
  }
  // Ladder rung 4: the interview verdict, only inside the tied top.
  if (interviewKind != null && tied.contains(interviewKind)) {
    return DominantResult(
      kind: interviewKind,
      tied: tied,
      rationale:
          'Tie on test performance — decided by your interview answers.',
    );
  }
  // Ladder rung 5: stay honest, report the balance.
  return DominantResult(
    kind: null,
    tied: tied,
    rationale:
        'Balanced profile — ${tied.length} types tied at the top, so no '
        'single winner is claimed.',
  );
}

/// One color chip of the visual assessment probe.
///
/// The name is the exact label the user reads AND taps: it must match
/// the rendered hue (a past bug showed a blue circle labeled "Purple"
/// and an orange one labeled "Yellow"). The [argb] value is the single
/// source of truth — the UI builds both the circle and the option
/// label from the same entry, so they can never drift apart again.
class AssessmentColorChip {
  final String name;
  final int argb;
  const AssessmentColorChip(this.name, this.argb);
}

/// Honest palette for the visual probes: six common, easily named
/// colors (Berlin & Kay basic color terms), visually distinct.
const assessmentColorChips = [
  AssessmentColorChip('Blue', 0xFF2F7CF6),
  AssessmentColorChip('Green', 0xFF22B07D),
  AssessmentColorChip('Orange', 0xFFFF9500),
  AssessmentColorChip('Red', 0xFFFF5A5A),
  AssessmentColorChip('Purple', 0xFF8B5CF6),
  AssessmentColorChip('Yellow', 0xFFEAB308),
];

/// First chip that is not in [shown] (the "which was NOT there" answer).
///
/// Never throws: when the whole palette is shown, the first chip is
/// returned as a deterministic stand-in instead of a StateError.
AssessmentColorChip chipNotAmong(List<AssessmentColorChip> shown) {
  final names = shown.map((c) => c.name).toSet();
  return assessmentColorChips.firstWhere(
    (c) => !names.contains(c.name),
    orElse: () => assessmentColorChips.first,
  );
}

/// True when every score is 0 (or there are no scores): nothing
/// meaningful was measured, so the UI must not crown a winner.
bool scoresAreBlank(List<int>? scores) {
  if (scores == null || scores.isEmpty) return true;
  return scores.every((s) => s <= 0);
}

/// Memory level from the mean of the 6 type scores (0-100 each).
///
/// Same `(avg ~/ 10) + 1` bands the profile and Battle Zone use:
/// level 1 (avg 0-9) up to level 11 (avg 100). This is an
/// app-internal progression metric, not a clinical instrument:
/// honest, coarse, and only comparable within the app.
int levelForScores(List<int> scores) {
  if (scores.isEmpty) return 1;
  final avg = scores.reduce((a, b) => a + b) ~/ scores.length;
  return (avg.clamp(0, 100) ~/ 10) + 1;
}

/// Stars for a finished lesson: 3 for a fast correct answer,
/// 2 for a correct answer, 1 for finishing with a mistake.
///
/// Speed counts because fluent retrieval (not just eventual recall)
/// is what transfers to real use; a finished lesson always earns
/// at least 1 star so effort is never punished with zero.
int starsForLesson({required bool correct, required Duration elapsed}) {
  if (!correct) return 1;
  if (elapsed < const Duration(seconds: 15)) return 3;
  return 2;
}
