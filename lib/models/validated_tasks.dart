/// Registry of validated memory paradigms behind every task.
///
/// Every drill in the app — lessons, benchmark, battle, assessment
/// fallbacks — is a small, faithful instance of one published paradigm
/// below. The AI never invents task formats: it only fills the stimulus
/// slots inside the paradigm's fixed procedure ([paradigmPrompt]), and
/// [validateTask] rejects any answer that breaks the structure, so the
/// caller falls back to the deterministic local generator
/// ([localValidatedTask]) running the same paradigm.
///
/// Bibliography: `docs/RESEARCH.md` section 8.
library;

import 'dart:math';

import 'meta_task.dart';
import 'palace_drill.dart'
    show concreteNouns, drillItemCount, localPalaceTask, localPictureTask;

/// Fixed procedure + response format of one validated paradigm.
class ParadigmSpec {
  /// Stable id stamped on every [MetaTask] (`task.paradigm`).
  final String id;

  /// Short UI label, e.g. "Backward digit span".
  final String display;

  /// What the learner does (fixed procedure, also sent to the AI).
  final String procedure;

  /// Stimulus rules the AI must obey (slot-filling only).
  final String stimulusRule;

  /// Response rules the AI must obey (always 4 options, 1 correct).
  final String responseRule;

  /// Study citation shown under the stimulus.
  final String source;

  /// Allowed stimulus item counts (AI answers outside fail validation).
  final int minItems;
  final int maxItems;

  const ParadigmSpec({
    required this.id,
    required this.display,
    required this.procedure,
    required this.stimulusRule,
    required this.responseRule,
    required this.source,
    required this.minItems,
    required this.maxItems,
  });
}

const _fourOptions =
    'Offer exactly 4 options, all different, exactly one correct.';

/// Backward digit span (WAIS): hear digits, report them reversed.
const ParadigmSpec backwardSpanSpec = ParadigmSpec(
  id: 'backward-span',
  display: 'Backward digit span',
  procedure:
      'Show single digits, then ask for the FULL order REVERSED. '
      'The correct option is the reversed sequence.',
  stimulusRule: 'Items are single digits (0-9), no two adjacent equal.',
  responseRule: '$_fourOptions Options are full orders joined with "-".',
  source: 'WAIS digit span; Baddeley 1986; Cowan 2001',
  minItems: 3,
  maxItems: 7,
);

/// Echoic / immediate probe (Peterson & Peterson): brief look, one probe.
const ParadigmSpec echoicProbeSpec = ParadigmSpec(
  id: 'echoic-probe',
  display: 'Echoic probe',
  procedure:
      'Show digits briefly once, then probe ONE position '
      '(e.g. "What was the 3rd digit?").',
  stimulusRule: 'Items are single digits (0-9), no two adjacent equal.',
  responseRule: '$_fourOptions Options are single digits.',
  source: 'Peterson & Peterson 1959; Baddeley & Hitch 1974',
  minItems: 3,
  maxItems: 7,
);

/// Chunked number recognition (Ericsson): one long number, recognize it.
const ParadigmSpec chunkSpanSpec = ParadigmSpec(
  id: 'chunk-span',
  display: 'Chunked number recall',
  procedure:
      'Show ONE multi-digit number, then ask which number was shown. '
      'Lures differ in 1-2 digits only, so chunking is required.',
  stimulusRule: 'Items hold exactly one number, 4-15 digits, no leading 0.',
  responseRule: '$_fourOptions Options are full numbers.',
  source: 'Miller 1956; Cowan 2001; Ericsson, Chase & Faloon 1980',
  minItems: 1,
  maxItems: 1,
);

/// Method-of-loci drill (Dresler training loop in miniature).
const ParadigmSpec lociDrillSpec = ParadigmSpec(
  id: 'loci-drill',
  display: 'Method-of-loci walk',
  procedure:
      'Ordered, distinct stations of ONE familiar route; one concrete '
      'imageable word per station. Probe: which word sits at one station.',
  stimulusRule:
      'Stations are ordered distinct place names; items are one concrete '
      'noun per station, same order, no repeats.',
  responseRule: '$_fourOptions Options are single nouns.',
  source: 'Maguire et al. 2003; Dresler et al. 2017',
  minItems: 4,
  maxItems: 8,
);

/// Picture recognition after one viewing (Shepard / Standing).
const ParadigmSpec pictureRecallSpec = ParadigmSpec(
  id: 'picture-recall',
  display: 'Picture recall',
  procedure:
      'Name ONE everyday scene and its visible details; probe asks which '
      'detail was in the scene (1 present + 3 absent from other scenes).',
  stimulusRule: 'Items are visible details of the named scene, no repeats.',
  responseRule: '$_fourOptions Options are single details.',
  source: 'Shepard 1967; Standing 1973; Paivio dual-coding',
  minItems: 4,
  maxItems: 8,
);

/// Visual pattern span on a 3x3 grid (change-detection family).
const ParadigmSpec patternSpanSpec = ParadigmSpec(
  id: 'pattern-span',
  display: 'Visual pattern span',
  procedure:
      'Light up cells of a 3x3 grid (indices 0-8, row by row), then ask '
      'which set was lit.',
  stimulusRule: 'Items are distinct cell indices 0-8.',
  responseRule: '$_fourOptions Options are index sets joined with ",".',
  source: 'Luck & Vogel 1997; Corsi 1972 spatial-span family',
  minItems: 2,
  maxItems: 6,
);

/// Story recall (WMS Logical Memory): single reading, cued detail.
const ParadigmSpec storyRecallSpec = ParadigmSpec(
  id: 'story-recall',
  display: 'Story recall',
  procedure:
      'Show ONE short story sentence once; probe asks one concrete detail '
      'from it (who / how many / what besides X).',
  stimulusRule: 'Items hold 1-2 story sentences with concrete details.',
  responseRule: '$_fourOptions Options are short detail phrases.',
  source: 'WMS Logical Memory; Craik & Tulving 1975',
  minItems: 1,
  maxItems: 2,
);

/// Category exemplar (Rosch / Battig norms): name the member.
const ParadigmSpec categoryExemplarSpec = ParadigmSpec(
  id: 'category-exemplar',
  display: 'Category exemplar',
  procedure:
      'Name a category; probe asks which option is a member. Hard lures '
      'are lookalikes from a neighboring category.',
  stimulusRule: 'Items hold exactly the category name.',
  responseRule: '$_fourOptions Options are single nouns.',
  source: 'Collins & Quillian 1969; Rosch 1975; Battig & Montague 1969',
  minItems: 1,
  maxItems: 1,
);

/// Cued paired associates (retrieval-practice loop): cue -> target.
const ParadigmSpec pairedAssociateSpec = ParadigmSpec(
  id: 'paired-associate',
  display: 'Paired associates',
  procedure:
      'Show a cue→target word pair once; probe shows the cue and asks '
      'for its target. Pure retrieval practice.',
  stimulusRule: 'Items hold one "cue → target" pair of concrete nouns.',
  responseRule: '$_fourOptions Options are single nouns.',
  source: 'Karpicke & Roediger 2008; Atkinson & Raugh 1975',
  minItems: 1,
  maxItems: 1,
);

/// Registry lookup by paradigm id (UI captions for stamped tasks).
ParadigmSpec specForId(String id) {
  for (final spec in [
    backwardSpanSpec,
    echoicProbeSpec,
    chunkSpanSpec,
    lociDrillSpec,
    pictureRecallSpec,
    patternSpanSpec,
    storyRecallSpec,
    categoryExemplarSpec,
    pairedAssociateSpec,
  ]) {
    if (spec.id == id) return spec;
  }
  return echoicProbeSpec;
}

/// Paradigm for a task kind (unknown kinds fall back to echoic probe,
/// the same digit-row drill the old default generator produced).
ParadigmSpec specForKind(String kind) {
  switch (kind) {
    case 'working':
    case 'sequence':
    case 'order':
    case 'duel':
      return backwardSpanSpec;
    case 'number':
      return chunkSpanSpec;
    case 'spatial':
      return lociDrillSpec;
    case 'visual':
      return pictureRecallSpec;
    case 'pattern':
      return patternSpanSpec;
    case 'episodic':
      return storyRecallSpec;
    case 'semantic':
      return categoryExemplarSpec;
    case 'verbal':
      return pairedAssociateSpec;
    case 'sensory':
    default:
      return echoicProbeSpec;
  }
}

/// Stimulus size the local generator uses for [kind] at [difficulty].
int itemCountFor(String kind, int difficulty) {
  final d = difficulty.clamp(1, 5);
  switch (specForKind(kind).id) {
    case 'backward-span':
    case 'echoic-probe':
      return 2 + d;
    case 'chunk-span':
      // 4 (Cowan ~4 limit) → 6 (2 chunks of 3) → 9 (3×3, Miller 7±2
      // ceiling) → 12 → 15 (multi-chunk training range, Ericsson et al.).
      return [4, 6, 9, 12, 15][d - 1];
    case 'loci-drill':
    case 'picture-recall':
      return drillItemCount(d);
    case 'pattern-span':
      return d + 1;
    default:
      return 1;
  }
}

/// Paradigm constraint block sent to the AI: fill the slots, never
/// change the procedure or the response format.
String paradigmPrompt(MetaTaskRequest req) {
  final spec = specForKind(req.kind);
  final n = itemCountFor(req.kind, req.difficulty);
  final size = spec.id == 'chunk-span'
      ? 'The number holds exactly $n digits.'
      : spec.minItems == spec.maxItems
      ? 'Show exactly ${spec.minItems} item(s).'
      : 'Show exactly $n items.';
  return 'PARADIGM "${spec.id}" (${spec.display}). Procedure: '
      '${spec.procedure} ${spec.stimulusRule} $size ${spec.responseRule} '
      'Do NOT invent another format, do NOT ask anything else, do NOT add '
      'keys. Echo the paradigm id in "paradigm".';
}

/// Structural violations of [task] against the paradigm of [req].
///
/// This checks the fixed procedure (counts, shapes, formats), not the
/// semantic truth of the stimulus — a wrong-but-wellformed AI answer is
/// still caught by [MetaTask.correct] pointing at the intended option.
List<String> validateTask(MetaTaskRequest req, MetaTask task) {
  final spec = specForKind(req.kind);
  final bad = <String>[];
  if (task.prompt.trim().isEmpty) bad.add('empty prompt');
  if (task.question.trim().isEmpty) bad.add('empty question');
  if (task.options.length != 4) bad.add('need exactly 4 options');
  if (task.correct < 0 || task.correct > 3) bad.add('correct out of range');
  if (task.options.any((o) => o.trim().isEmpty)) bad.add('empty option');
  if (task.options.map((o) => o.trim()).toSet().length != task.options.length) {
    bad.add('options must differ');
  }
  if (task.items.isEmpty) bad.add('empty stimulus');
  if (task.items.length < spec.minItems || task.items.length > spec.maxItems) {
    bad.add('items outside ${spec.minItems}-${spec.maxItems}');
  }
  if (task.items.any((e) => e.trim().isEmpty)) bad.add('empty item');
  final digitKinds = {'backward-span', 'echoic-probe'};
  if (digitKinds.contains(spec.id)) {
    if (task.items.any((e) => !RegExp(r'^\d$').hasMatch(e.trim()))) {
      bad.add('items must be single digits');
    }
  }
  if (spec.id == 'chunk-span') {
    final item = task.items.isEmpty ? '' : task.items.first.trim();
    if (!RegExp(r'^[1-9]\d{3,14}$').hasMatch(item)) {
      bad.add('item must be a 4-15 digit number');
    }
    if (task.options.any((o) => !RegExp(r'^\d+$').hasMatch(o.trim()))) {
      bad.add('options must be numbers');
    }
  }
  if (spec.id == 'pattern-span') {
    if (task.items.any((e) {
      final v = int.tryParse(e.trim());
      return v == null || v < 0 || v > 8;
    })) {
      bad.add('items must be cells 0-8');
    }
  }
  if (spec.id == 'loci-drill' &&
      task.stations.isNotEmpty &&
      task.stations.length != task.items.length) {
    bad.add('stations must match items one by one');
  }
  return bad;
}

int _seedHash(String seed) {
  var h = 0x811c9dc5;
  for (final c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

String _ordinal(int k) {
  if (k == 1) return '1st';
  if (k == 2) return '2nd';
  if (k == 3) return '3rd';
  return '${k}th';
}

List<String> _digits(Random rnd, int n) {
  final out = <String>[];
  while (out.length < n) {
    final d = '${rnd.nextInt(10)}';
    if (out.isNotEmpty && out.last == d) continue;
    out.add(d);
  }
  return out;
}

/// Fixed story bank: one-reading sentences with one cued detail each
/// (Logical-Memory style idea units, matched difficulty).
const _stories = [
  (
    story: 'On Monday Peter mailed 3 letters and a small parcel at the post office.',
    question: 'What did Peter mail besides the parcel?',
    correct: '3 letters',
    lures: ['2 letters', '4 postcards', 'A newspaper'],
  ),
  (
    story: 'In the evening Nora cooked fish soup and baked a round loaf for her guests.',
    question: 'What did Nora bake for her guests?',
    correct: 'A round loaf',
    lures: ['A pie', 'Two baguettes', 'A chocolate cake'],
  ),
  (
    story: 'At dawn the old ferry carried 12 cars and a red fire truck across the river.',
    question: 'What crossed the river besides the cars?',
    correct: 'A red fire truck',
    lures: ['A blue bus', 'A police car', 'An ambulance'],
  ),
  (
    story: 'After lunch the twins borrowed 2 bikes and a green tent from their uncle.',
    question: 'What did the twins borrow besides the tent?',
    correct: '2 bikes',
    lures: ['3 bikes', 'A canoe', 'A guitar'],
  ),
  (
    story: 'Before the storm Anna closed 5 windows and fed the black cat on the porch.',
    question: 'What did Anna do besides closing the windows?',
    correct: 'Fed the black cat',
    lures: ['Fed the white dog', 'Locked the gate', 'Lit a lantern'],
  ),
  (
    story: 'At noon the museum guide showed 40 pupils a golden mask from Egypt.',
    question: 'What did the guide show the pupils?',
    correct: 'A golden mask',
    lures: ['A silver sword', 'A marble statue', 'An old map'],
  ),
];

/// Fixed category bank with prototype answers and neighbor-category lures
/// (Battig & Montague / Van Overschelde norms family).
const _categories = [
  (
    category: 'Fruits',
    correct: 'Apple',
    lures: ['Carrot', 'Potato', 'Onion'],
  ),
  (
    category: 'Vegetables',
    correct: 'Carrot',
    lures: ['Apple', 'Pear', 'Grape'],
  ),
  (
    category: 'Mammals',
    correct: 'Dolphin',
    lures: ['Shark', 'Penguin', 'Crocodile'],
  ),
  (
    category: 'Birds',
    correct: 'Penguin',
    lures: ['Bat', 'Butterfly', 'Bee'],
  ),
  (
    category: 'Tools',
    correct: 'Hammer',
    lures: ['Nail', 'Flowerpot', 'Candle'],
  ),
  (
    category: 'Musical instruments',
    correct: 'Violin',
    lures: ['Radio', 'Ladder', 'Mirror'],
  ),
  (
    category: 'Vehicles',
    correct: 'Bicycle',
    lures: ['Stroller', 'Swing', 'Tent'],
  ),
  (
    category: 'Furniture',
    correct: 'Bookshelf',
    lures: ['Carpet', 'Lamp', 'Curtain'],
  ),
];

/// Deterministic local task inside the paradigm of [req].
///
/// Same [req.seed] always yields the same task, so lessons are stable
/// and tests are reproducible. An empty seed draws fresh randomness
/// (benchmark sparring, battle duels).
MetaTask localValidatedTask(MetaTaskRequest req) {
  final spec = specForKind(req.kind);
  final seed = req.seed.isEmpty ? 'fresh:${DateTime.now().microsecondsSinceEpoch}:${req.kind}' : req.seed;
  // Spatial / visual lessons keep their dedicated drill builders, which
  // already implement the loci and picture paradigms (stamped below).
  if (spec.id == 'loci-drill') {
    return localPalaceTask(difficulty: req.difficulty, seed: seed).copyWith(
      paradigm: spec.id,
      source: spec.source,
    );
  }
  if (spec.id == 'picture-recall') {
    return localPictureTask(difficulty: req.difficulty, seed: seed).copyWith(
      paradigm: spec.id,
      source: spec.source,
    );
  }
  final rnd = Random(_seedHash('${spec.id}:$seed'));
  final now = DateTime.now();
  switch (spec.id) {
    case 'backward-span':
      return _backwardSpan(rnd, req, spec, now);
    case 'chunk-span':
      return _chunkSpan(rnd, req, spec, now);
    case 'pattern-span':
      return _patternSpan(rnd, req, spec, now);
    case 'story-recall':
      return _storyRecall(rnd, spec, now);
    case 'category-exemplar':
      return _categoryExemplar(rnd, spec, now);
    case 'paired-associate':
      return _pairedAssociate(rnd, spec, now);
    case 'echoic-probe':
    default:
      return _echoicProbe(rnd, req, spec, now);
  }
}

MetaTask _echoicProbe(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
) {
  final n = itemCountFor(req.kind, req.difficulty);
  final digits = _digits(rnd, n);
  final k = rnd.nextInt(n);
  final answer = digits[k];
  final options = <String>[answer];
  while (options.length < 4) {
    final lure = '${rnd.nextInt(10)}';
    if (!options.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Memorize these digits — one quick look!',
    items: digits,
    question: 'What was the ${_ordinal(k + 1)} digit?',
    options: options,
    correct: options.indexOf(answer),
    explanation:
        'Say the row aloud once, then probe it — immediate recall with a '
        'brief look is the echoic paradigm. (Peterson & Peterson 1959)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _backwardSpan(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
) {
  final n = itemCountFor(req.kind, req.difficulty);
  final digits = _digits(rnd, n);
  final reversed = digits.reversed.join('-');
  final options = <String>[reversed];
  // Deterministic lure family: forward, two swaps, rotation.
  String join(List<String> l) => l.join('-');
  final rev = digits.reversed.toList();
  final lures = <String>[
    join(digits),
    join([...rev]..swapFirstTwo()),
    join([...rev]..swapLastTwo()),
    join([...rev.sublist(1), rev.first]),
  ];
  for (final lure in lures) {
    if (options.length >= 4) break;
    if (lure != reversed && !options.contains(lure)) options.add(lure);
  }
  while (options.length < 4) {
    final extra = _digits(rnd, n).join('-');
    if (!options.contains(extra)) options.add(extra);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Hold these digits, then reverse them!',
    items: digits,
    question: 'What is the full order REVERSED?',
    options: options,
    correct: options.indexOf(reversed),
    explanation:
        'Hold the whole set first, then work backwards one item at a '
        'time. Backward span taxes the central executive. '
        '(Baddeley & Hitch 1974)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _chunkSpan(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
) {
  final len = itemCountFor(req.kind, req.difficulty);
  String fresh() {
    final sb = StringBuffer('${1 + rnd.nextInt(9)}');
    for (var i = 1; i < len; i++) {
      sb.write(rnd.nextInt(10));
    }
    return sb.toString();
  }

  final num = fresh();
  final options = <String>[num];
  while (options.length < 4) {
    final chars = num.split('');
    // Mutate 1-2 positions so only chunking carries the recall.
    for (var m = 0; m < (len > 8 ? 2 : 1); m++) {
      final at = rnd.nextInt(len);
      chars[at] = '${rnd.nextInt(10)}';
    }
    final lure = chars.join();
    if (lure != num && !options.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Memorize this number!',
    items: [num],
    question: 'Which number did you see?',
    options: options,
    correct: options.indexOf(num),
    explanation:
        'Chunk it in threes and turn each chunk into one image — $len '
        'digits are just a few chunks. (Miller 1956; Ericsson et al. 1980)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _patternSpan(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
) {
  final count = itemCountFor(req.kind, req.difficulty);
  final cells = <int>{};
  while (cells.length < count) {
    cells.add(rnd.nextInt(9));
  }
  final correct = (cells.toList()..sort()).join(',');
  final options = <String>[correct];
  while (options.length < 4) {
    final mutated = cells.toList();
    mutated[rnd.nextInt(mutated.length)] = rnd.nextInt(9);
    final set = mutated.toSet();
    if (set.length != count) continue;
    final lure = (set.toList()..sort()).join(',');
    if (lure != correct && !options.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Memorize the lit cells!',
    items: cells.map((c) => '$c').toList(),
    question: 'Which cells were lit?',
    options: options,
    correct: options.indexOf(correct),
    explanation:
        'See the lit cells as ONE shape, not separate dots — visual '
        'working memory holds about 4 objects. (Luck & Vogel 1997)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _storyRecall(Random rnd, ParadigmSpec spec, DateTime now) {
  final s = _stories[rnd.nextInt(_stories.length)];
  final options = <String>[s.correct, ...s.lures]..shuffle(rnd);
  return MetaTask(
    prompt: 'Read carefully, just once!',
    items: [s.story],
    question: s.question,
    options: options,
    correct: options.indexOf(s.correct),
    explanation:
        'Replay the scene as a short movie while you read — elaborated '
        'stories stick. (Craik & Tulving 1975)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _categoryExemplar(Random rnd, ParadigmSpec spec, DateTime now) {
  final c = _categories[rnd.nextInt(_categories.length)];
  final options = <String>[c.correct, ...c.lures]..shuffle(rnd);
  return MetaTask(
    prompt: 'Think about the meaning!',
    items: [c.category],
    question: 'Which one is this?',
    options: options,
    correct: options.indexOf(c.correct),
    explanation:
        'Name what makes the prototype a member — meaning webs beat rote '
        'lists. (Rosch 1975)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _pairedAssociate(Random rnd, ParadigmSpec spec, DateTime now) {
  final pool = List<String>.of(concreteNouns)..shuffle(rnd);
  final cue = pool[0];
  final target = pool[1];
  final options = <String>[target];
  for (var i = 2; i < pool.length && options.length < 4; i++) {
    options.add(pool[i]);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: 'Learn this pair: $cue goes with $target!',
    items: ['$cue → $target'],
    question: 'What went with "$cue"?',
    options: options,
    correct: options.indexOf(target),
    explanation:
        'Link cue and target in ONE bizarre interacting image, then test '
        'yourself — retrieval beats re-study. (Karpicke & Roediger 2008)',
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

extension on List<String> {
  void swapFirstTwo() {
    if (length >= 2) {
      final t = this[0];
      this[0] = this[1];
      this[1] = t;
    }
  }

  void swapLastTwo() {
    if (length >= 2) {
      final t = this[length - 1];
      this[length - 1] = this[length - 2];
      this[length - 2] = t;
    }
  }
}
