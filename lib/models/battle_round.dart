library;

import '../l10n/app_localizations.dart';
import 'meta_task.dart';
import 'recall_scoring.dart'
    show RecallScore, scoreCellSet, scoreTaskRecall;

/// How one battle round is answered.
///
/// Typed recall and grid production replace 4-option recognition wherever
/// the paradigm allows it: recall formats beat recognition (Rowland 2014,
/// g=0.50; Adesope et al. 2017, g=0.51), and production answers cannot be
/// solved by visual comparison while the stimulus stays on screen.
enum BattleResponseKind {
  /// Full digit order typed from memory (backward span).
  typedDigits,

  /// One token typed from memory (iconic digit, picture detail, pair target).
  typedToken,

  /// Lit cells tapped back on a blank 3x3 grid (pattern span).
  cellSet,

  /// Semantic exemplar judgment. Stays 4-option recognition: judgment IS
  /// the Rosch paradigm (Collins & Quillian 1969; Rosch 1975).
  choice4,
}

/// Battle request kind per memory-kind index (0..5 =
/// sensory, working, spatial, visual, episodic, semantic).
///
/// This mapping is battle-only and independent of lessons. Every pick is a
/// registry paradigm (`lib/models/validated_tasks.dart`) whose battle
/// response format resists cheating:
/// - sensory -> iconic-probe, typed digit (Sperling 1960);
/// - working -> backward-span, typed reversed order (WAIS; Baddeley 1986);
/// - spatial -> pattern-span, tapped cell set (Luck & Vogel 1997);
/// - visual -> picture-recall, typed detail (Shepard 1967; Standing 1973);
/// - episodic -> paired-associate, typed target (Karpicke & Roediger 2008);
/// - semantic -> category-exemplar, 4-choice judgment (Rosch 1975).
const battleRequestKinds = <String>[
  'sensory',
  'working',
  'pattern',
  'visual',
  'verbal',
  'semantic',
];

/// Request kind for a memory-kind index, clamped to 0..5.
String battleRequestKindFor(int kindIndex) =>
    battleRequestKinds[kindIndex.clamp(0, battleRequestKinds.length - 1)];

/// Response format for a battle request kind.
BattleResponseKind battleResponseKindForRequest(String requestKind) {
  switch (requestKind) {
    case 'working':
      return BattleResponseKind.typedDigits;
    case 'pattern':
      return BattleResponseKind.cellSet;
    case 'semantic':
      return BattleResponseKind.choice4;
    default:
      return BattleResponseKind.typedToken;
  }
}

/// Response format for a task paradigm. The duel derives its UI from the
/// stamped paradigm (never from the request alone), so even an unexpected
/// paradigm degrades to a sane input: sequences typed, sets tapped,
/// judgments picked, everything else typed as one token.
BattleResponseKind battleResponseKindForParadigm(String paradigm) {
  switch (paradigm) {
    case 'backward-span':
    case 'chunk-span':
    case 'brown-peterson':
      return BattleResponseKind.typedDigits;
    case 'pattern-span':
      return BattleResponseKind.cellSet;
    case 'category-exemplar':
      return BattleResponseKind.choice4;
    default:
      return BattleResponseKind.typedToken;
  }
}

/// Duel paradigms that gain an AI illustration (Muse Image) plus SAM detail
/// labels. The picture is the stimulus itself for picture-recall, and a
/// memory hook next to the words otherwise. Digit spans and the tap grid
/// stay clean: extra pixels would only add noise to the trace.
const battleImageryParadigms = <String>{
  'picture-recall',
  'paired-associate',
  'category-exemplar',
};

/// Whether a duel task wants an AI illustration for its encode phase.
bool battleTaskWantsImage(MetaTask task) =>
    battleImageryParadigms.contains(task.paradigm);

/// Three-round duel plan: the chosen kind first, then two interleaved kinds
/// (rotation by +2/+4). Every duel mixes procedures, because interleaved
/// practice beats blocked practice (Rohrer & Taylor 2007; Brunmair &
/// Richter 2019 meta-analysis, g=0.42). Deterministic, so both sides always
/// share the same plan.
List<int> battleRoundKinds(int chosen) {
  final c = chosen.clamp(0, 5);
  return [c, (c + 2) % 6, (c + 4) % 6];
}

/// Encode (memorize) time for a battle task in milliseconds.
///
/// The stimulus auto-hides when the budget runs out: iconic traces decay in
/// ~0.5 s (Sperling 1960), so brief fixed exposure plus immediate probing
/// is the paradigm — not a trick. Semantic judgment needs no encode phase
/// (returns 0): there is nothing to memorize.
int battleEncodeMs(MetaTask task, {required int difficulty}) {
  switch (task.paradigm) {
    case 'backward-span':
      return 2000 + task.items.length * 1200;
    case 'iconic-probe':
    case 'echoic-probe':
      return difficulty >= 3 ? 6000 : 4000;
    case 'pattern-span':
      return 3000 + task.items.length * 600;
    case 'picture-recall':
      return difficulty >= 3 ? 8000 : 6000;
    case 'paired-associate':
      return 5000;
    case 'category-exemplar':
      return 0;
    default:
      return 5000;
  }
}

/// Recall (answer) clock per response kind in milliseconds. Both sides share
/// the same clock every round. Typed recall gets the longest window:
/// production is harder than recognition, and the clock must measure memory,
/// not typing speed.
int battleRecallMs(BattleResponseKind kind) {
  switch (kind) {
    case BattleResponseKind.typedDigits:
    case BattleResponseKind.typedToken:
      return 30000;
    case BattleResponseKind.cellSet:
      return 20000;
    case BattleResponseKind.choice4:
      return 15000;
  }
}

/// Encode-phase instruction. Backward span stays direction-blind: revealing
/// "reversed" upfront lets players encode backwards directly, which removes
/// the hold-then-manipulate load the span exists to measure (Baddeley 1986;
/// same rule as the assessment probes).
String battleEncodePrompt(MetaTask task) {
  if (task.paradigm == 'backward-span') {
    return 'Hold these digits — the direction comes next!';
  }
  return task.prompt;
}

String battleEncodePromptIn(String locale, MetaTask task) {
  if (task.paradigm == 'backward-span') {
    return trFor(locale, 'btl_encode_hold');
  }
  return task.prompt;
}

/// Recall input hint per paradigm. Never leaks the answer.
String battleRecallHint(MetaTask task) {
  switch (task.paradigm) {
    case 'backward-span':
      return 'Type the full order…';
    case 'iconic-probe':
    case 'echoic-probe':
      return 'Type the digit…';
    case 'picture-recall':
      return 'Type the detail…';
    case 'paired-associate':
      return 'Type its pair…';
    default:
      return 'Type your answer…';
  }
}

String battleRecallHintIn(String locale, MetaTask task) {
  switch (task.paradigm) {
    case 'backward-span':
      return trFor(locale, 'btl_hint_order');
    case 'iconic-probe':
    case 'echoic-probe':
      return trFor(locale, 'btl_hint_digit');
    case 'picture-recall':
      return trFor(locale, 'btl_hint_detail');
    case 'paired-associate':
      return trFor(locale, 'btl_hint_pair');
    default:
      return trFor(locale, 'btl_hint_answer');
  }
}

/// Numeric keyboard for digit paradigms, text otherwise.
bool battleWantsNumericKeyboard(MetaTask task) {
  switch (task.paradigm) {
    case 'backward-span':
    case 'iconic-probe':
    case 'echoic-probe':
    case 'chunk-span':
      return true;
    default:
      return false;
  }
}

/// Correct answer text for the reveal screen (corrective feedback roughly
/// doubles the testing effect; Rowland 2014).
String battleAnswerKey(MetaTask task) {
  if (task.correct < 0 || task.correct >= task.options.length) return '';
  return task.options[task.correct];
}

/// Expected lit cells for pattern-span tasks (indices 0-8).
List<int> battleExpectedCells(MetaTask task) {
  return [
    for (final e in task.items) int.tryParse(e.trim()) ?? -1,
  ].where((c) => c >= 0 && c <= 8).toList();
}

/// Scores a typed or tapped battle response with the shared free-recall
/// engine. Pattern-span taps score as a set with false-alarm penalty
/// ([scoreCellSet]); everything else dispatches per paradigm
/// ([scoreTaskRecall]). The expected answer always comes from the validated
/// key — responses never define their own truth.
RecallScore battleScoreResponse(
  MetaTask task, {
  String text = '',
  List<int> taps = const [],
}) {
  if (task.paradigm == 'pattern-span') {
    return scoreCellSet(battleExpectedCells(task), taps.join(','));
  }
  return scoreTaskRecall(task, text);
}

/// Whether the player gave a scorable (non-empty) response. Empty typing,
/// zero taps and no pick count as unanswered, so idle stalling cannot farm
/// participation XP.
bool battleResponsePresent(
  BattleResponseKind kind, {
  String text = '',
  List<int> taps = const [],
  int choice = -1,
}) {
  switch (kind) {
    case BattleResponseKind.typedDigits:
    case BattleResponseKind.typedToken:
      return text.trim().isNotEmpty;
    case BattleResponseKind.cellSet:
      return taps.isNotEmpty;
    case BattleResponseKind.choice4:
      return choice >= 0;
  }
}
