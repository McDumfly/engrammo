library;

import 'dart:math';

import '../l10n/app_localizations.dart';
import 'item_banks.dart'
    show
        dayEventPoolFor,
        faceNameBankFor,
        foreignWordBankFor,
        poemBankFor,
        prospectiveBankFor,
        spareCategoriesFor,
        spareStoriesFor;
import 'meta_task.dart';
import 'palace_drill.dart'
    show
        allConcreteNounsFor,
        drillItemCount,
        localPalaceTask,
        localPictureTask;

class ParadigmSpec {
  final String id;

  final String displayKey;

  final String procedure;

  final String stimulusRule;

  final String responseRule;

  final String source;

  final int minItems;
  final int maxItems;

  const ParadigmSpec({
    required this.id,
    required this.displayKey,
    required this.procedure,
    required this.stimulusRule,
    required this.responseRule,
    required this.source,
    required this.minItems,
    required this.maxItems,
  });

  String get displayName => tr(displayKey);

  String get display => enText(displayKey);
}

const _fourOptions =
    'Offer exactly 4 options, all different, exactly one correct.';

const ParadigmSpec backwardSpanSpec = ParadigmSpec(
  id: 'backward-span',
  displayKey: 'paradigm_backward_span',
  procedure:
      'Show single digits, then ask for the FULL order REVERSED. '
      'The correct option is the reversed sequence.',
  stimulusRule: 'Items are single digits (0-9), no two adjacent equal.',
  responseRule: '$_fourOptions Options are full orders joined with "-".',
  source: 'WAIS digit span; Baddeley 1986; Cowan 2001',
  minItems: 3,
  maxItems: 7,
);

const ParadigmSpec iconicProbeSpec = ParadigmSpec(
  id: 'iconic-probe',
  displayKey: 'paradigm_iconic_probe',
  procedure:
      'Show digits briefly once, then probe ONE position '
      '(e.g. "What was the 3rd digit?").',
  stimulusRule: 'Items are single digits (0-9), no two adjacent equal.',
  responseRule: '$_fourOptions Options are single digits.',
  source: 'Sperling 1960; Luck & Vogel 1997',
  minItems: 3,
  maxItems: 7,
);

const ParadigmSpec echoicProbeSpec = ParadigmSpec(
  id: 'echoic-probe',
  displayKey: 'paradigm_iconic_probe',
  procedure:
      'Show digits briefly once, then probe ONE position '
      '(e.g. "What was the 3rd digit?").',
  stimulusRule: 'Items are single digits (0-9), no two adjacent equal.',
  responseRule: '$_fourOptions Options are single digits.',
  source: 'Sperling 1960; Luck & Vogel 1997',
  minItems: 3,
  maxItems: 7,
);

const ParadigmSpec brownPetersonSpec = ParadigmSpec(
  id: 'brown-peterson',
  displayKey: 'paradigm_interference',
  procedure:
      'Show ONE consonant trigram (e.g. XJR), run a count-backwards-by-3 '
      'distractor for the stated seconds, then ask for the trigram.',
  stimulusRule:
      'Items hold exactly one trigram: 3 distinct uppercase consonants '
      '(no vowels, no repeats).',
  responseRule: '$_fourOptions Options are single trigrams.',
  source: 'Peterson & Peterson 1959; Brown 1958',
  minItems: 1,
  maxItems: 1,
);

int brownPetersonDelay(int difficulty) {
  const delays = [3, 3, 6, 9, 18];
  return delays[difficulty.clamp(1, 5) - 1];
}

const ParadigmSpec chunkSpanSpec = ParadigmSpec(
  id: 'chunk-span',
  displayKey: 'paradigm_chunk_span',
  procedure:
      'Show ONE multi-digit number, then ask which number was shown. '
      'Lures differ in 1-2 digits only, so chunking is required.',
  stimulusRule: 'Items hold exactly one number, 4-15 digits, no leading 0.',
  responseRule: '$_fourOptions Options are full numbers.',
  source: 'Miller 1956; Cowan 2001; Ericsson, Chase & Faloon 1980',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec lociDrillSpec = ParadigmSpec(
  id: 'loci-drill',
  displayKey: 'paradigm_loci',
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

const ParadigmSpec pictureRecallSpec = ParadigmSpec(
  id: 'picture-recall',
  displayKey: 'paradigm_picture',
  procedure:
      'Name ONE everyday scene and its visible details; probe asks which '
      'detail was in the scene (1 present + 3 absent from other scenes).',
  stimulusRule: 'Items are visible details of the named scene, no repeats.',
  responseRule: '$_fourOptions Options are single details.',
  source: 'Shepard 1967; Standing 1973; Paivio dual-coding',
  minItems: 4,
  maxItems: 8,
);

const ParadigmSpec patternSpanSpec = ParadigmSpec(
  id: 'pattern-span',
  displayKey: 'paradigm_pattern',
  procedure:
      'Light up cells of a 3x3 grid (indices 0-8, row by row), then ask '
      'which set was lit.',
  stimulusRule: 'Items are distinct cell indices 0-8.',
  responseRule: '$_fourOptions Options are index sets joined with ",".',
  source: 'Luck & Vogel 1997; Cowan 2001',
  minItems: 2,
  maxItems: 6,
);

const ParadigmSpec storyRecallSpec = ParadigmSpec(
  id: 'story-recall',
  displayKey: 'paradigm_story',
  procedure:
      'Show ONE short story sentence once; probe asks one concrete detail '
      'from it (who / how many / what besides X).',
  stimulusRule: 'Items hold 1-2 story sentences with concrete details.',
  responseRule: '$_fourOptions Options are short detail phrases.',
  source: 'WMS Logical Memory; Craik & Tulving 1975',
  minItems: 1,
  maxItems: 2,
);

const ParadigmSpec categoryExemplarSpec = ParadigmSpec(
  id: 'category-exemplar',
  displayKey: 'paradigm_category',
  procedure:
      'Name a category; probe asks which option is a member. Hard lures '
      'are lookalikes from a neighboring category.',
  stimulusRule: 'Items hold exactly the category name.',
  responseRule: '$_fourOptions Options are single nouns.',
  source: 'Collins & Quillian 1969; Rosch 1975; Battig & Montague 1969',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec pairedAssociateSpec = ParadigmSpec(
  id: 'paired-associate',
  displayKey: 'paradigm_paired',
  procedure:
      'Show a cue→target word pair once; probe shows the cue and asks '
      'for its target. Pure retrieval practice.',
  stimulusRule: 'Items hold one "cue → target" pair of concrete nouns.',
  responseRule: '$_fourOptions Options are single nouns.',
  source: 'Karpicke & Roediger 2008; Atkinson & Raugh 1975',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec faceNameSpec = ParadigmSpec(
  id: 'face-name',
  displayKey: 'paradigm_face',
  procedure:
      'Show ONE face feature plus its name hook once; probe names the '
      'feature and asks which surname goes with it.',
  stimulusRule:
      'Items hold one "feature → Name (hook)" pair; features name one '
      'distinct facial feature, names are single surnames.',
  responseRule: '$_fourOptions Options are single surnames.',
  source: 'Morris et al. face-name mnemonic; McWeeny et al. 1987',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec keywordPairSpec = ParadigmSpec(
  id: 'keyword-pair',
  displayKey: 'paradigm_keyword',
  procedure:
      'Show ONE foreign word with its keyword hook and meaning once; '
      'probe shows the foreign word and asks for its meaning.',
  stimulusRule:
      'Items hold one "foreign (keyword) → meaning" triple of single '
      'imageable words.',
  responseRule: '$_fourOptions Options are single meanings.',
  source: 'Atkinson & Raugh 1975; Beaton et al. 1995',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec prospectiveCueSpec = ParadigmSpec(
  id: 'prospective-cue',
  displayKey: 'paradigm_prospective',
  procedure:
      'Show ONE "WHEN cue → THEN action" plan once; probe names the '
      'WHEN cue and asks for the THEN action.',
  stimulusRule:
      'Items hold one "WHEN cue → THEN action" pair of short everyday '
      'phrases; lures are other plausible actions.',
  responseRule: '$_fourOptions Options are short action phrases.',
  source: 'Gollwitzer (1999); Einstein & McDaniel (1990)',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec poemChunkSpec = ParadigmSpec(
  id: 'poem-chunk',
  displayKey: 'paradigm_poem',
  procedure:
      'Show ONE two-line verse chunk once; probe shows line 1 and asks '
      'for line 2.',
  stimulusRule:
      'Items hold one "line 1 / line 2" pair of short verse lines; '
      'lures are other verse lines.',
  responseRule: '$_fourOptions Options are single verse lines.',
  source: 'Rubin (1995); Roediger & Karpicke (2006)',
  minItems: 1,
  maxItems: 1,
);

const ParadigmSpec dayReplaySpec = ParadigmSpec(
  id: 'day-replay',
  displayKey: 'paradigm_day',
  procedure:
      'Show 3-5 ordered everyday events once; probe names one event '
      'and asks what came right AFTER it.',
  stimulusRule:
      'Items are ordered distinct everyday events, same order, no '
      'repeats; the probed event is never the last one.',
  responseRule: '$_fourOptions Options are single events.',
  source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
  minItems: 3,
  maxItems: 5,
);

ParadigmSpec specForId(String id) {
  if (id == 'echoic-probe') return iconicProbeSpec;
  for (final spec in [
    backwardSpanSpec,
    iconicProbeSpec,
    brownPetersonSpec,
    chunkSpanSpec,
    lociDrillSpec,
    pictureRecallSpec,
    patternSpanSpec,
    storyRecallSpec,
    categoryExemplarSpec,
    pairedAssociateSpec,
    faceNameSpec,
    keywordPairSpec,
    prospectiveCueSpec,
    poemChunkSpec,
    dayReplaySpec,
  ]) {
    if (spec.id == id) return spec;
  }
  return iconicProbeSpec;
}

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
    case 'face':
      return faceNameSpec;
    case 'foreign':
      return keywordPairSpec;
    case 'prospective':
      return prospectiveCueSpec;
    case 'poem':
      return poemChunkSpec;
    case 'replay':
      return dayReplaySpec;
    case 'interference':
      return brownPetersonSpec;
    case 'sensory':
    default:
      return iconicProbeSpec;
  }
}

int itemCountFor(String kind, int difficulty) {
  final d = difficulty.clamp(1, 5);
  switch (specForKind(kind).id) {
    case 'backward-span':
    case 'iconic-probe':
    case 'echoic-probe':
      return 2 + d;
    case 'chunk-span':
      return [4, 6, 9, 12, 15][d - 1];
    case 'loci-drill':
    case 'picture-recall':
      return drillItemCount(d);
    case 'day-replay':
      return [3, 3, 4, 4, 5][d - 1];
    case 'pattern-span':
      return d + 1;
    default:
      return 1;
  }
}

String paradigmPrompt(MetaTaskRequest req) {
  final spec = specForKind(req.kind);
  final n = itemCountFor(req.kind, req.difficulty);
  final size = spec.id == 'chunk-span'
      ? 'The number holds exactly $n digits.'
      : spec.minItems == spec.maxItems
      ? 'Show exactly ${spec.minItems} item(s).'
      : 'Show exactly $n items.';
  final extra = spec.id == 'brown-peterson'
      ? 'Distractor before recall: count backwards by 3 from 100 for '
          '${brownPetersonDelay(req.difficulty)} seconds. '
      : '';
  return 'PARADIGM "${spec.id}" (${enText(spec.displayKey)}). Procedure: '
      '${spec.procedure} ${spec.stimulusRule} $size $extra'
      '${spec.responseRule} '
      'Do NOT invent another format, do NOT ask anything else, do NOT add '
      'keys. Echo the paradigm id in "paradigm".';
}

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
  final digitKinds = {'backward-span', 'iconic-probe', 'echoic-probe'};
  if (digitKinds.contains(spec.id)) {
    if (task.items.any((e) => !RegExp(r'^\d$').hasMatch(e.trim()))) {
      bad.add('items must be single digits');
    }
  }
  if (spec.id == 'brown-peterson') {
    final trigram = RegExp(r'^[BCDFGHJKLMNPQRSTVWXYZ]{3}$');
    bool wellformed(String s) {
      final t = s.trim().toUpperCase();
      return trigram.hasMatch(t) &&
          t[0] != t[1] &&
          t[1] != t[2] &&
          t[0] != t[2];
    }

    if (task.items.length != 1 || !wellformed(task.items.first)) {
      bad.add('item must be one CCC trigram (distinct consonants)');
    }
    if (task.options.any((o) => !wellformed(o))) {
      bad.add('options must be trigrams');
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
  if (spec.id == 'day-replay') {
    if (task.items.map((e) => e.trim()).toSet().length != task.items.length) {
      bad.add('day events must be distinct');
    }
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

String _ordinal(int k, [String locale = 'en']) {
  if (locale == 'hu') return '$k.';
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

MetaTask localValidatedTask(MetaTaskRequest req) {
  final spec = specForKind(req.kind);
  final seed = req.seed.isEmpty ? 'fresh:${DateTime.now().microsecondsSinceEpoch}:${req.kind}' : req.seed;
  if (spec.id == 'loci-drill') {
    return localPalaceTask(
      difficulty: req.difficulty,
      seed: seed,
      locale: req.locale,
    ).copyWith(paradigm: spec.id, source: spec.source);
  }
  if (spec.id == 'picture-recall') {
    return localPictureTask(
      difficulty: req.difficulty,
      seed: seed,
      locale: req.locale,
    ).copyWith(paradigm: spec.id, source: spec.source);
  }
  final rnd = Random(_seedHash('${spec.id}:$seed'));
  final now = DateTime.now();
  switch (spec.id) {
    case 'backward-span':
      return _backwardSpan(rnd, req, spec, now, req.locale);
    case 'chunk-span':
      return _chunkSpan(rnd, req, spec, now, req.locale);
    case 'pattern-span':
      return _patternSpan(rnd, req, spec, now, req.locale);
    case 'story-recall':
      return _storyRecall(rnd, spec, now, req.locale);
    case 'category-exemplar':
      return _categoryExemplar(rnd, spec, now, req.locale);
    case 'paired-associate':
      return _pairedAssociate(rnd, spec, now, req.locale);
    case 'face-name':
      return _faceName(rnd, spec, now, req.locale);
    case 'keyword-pair':
      return _keywordPair(rnd, spec, now, req.locale);
    case 'prospective-cue':
      return _prospectiveCue(rnd, spec, now, req.locale);
    case 'poem-chunk':
      return _poemChunk(rnd, spec, now, req.locale);
    case 'day-replay':
      return _dayReplay(rnd, req, spec, now, req.locale);
    case 'brown-peterson':
      return _brownPeterson(rnd, req, spec, now, req.locale);
    case 'iconic-probe':
    case 'echoic-probe':
    default:
      return _iconicProbe(rnd, req, spec, now, req.locale);
  }
}

MetaTask _iconicProbe(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
  String locale,
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
    prompt: trFor(locale, 'task_iconic_prompt'),
    items: digits,
    question: trFor(locale, 'task_iconic_q', {
      'ord': _ordinal(k + 1, locale),
    }),
    options: options,
    correct: options.indexOf(answer),
    explanation: trFor(locale, 'task_iconic_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

const _consonants = 'BCDFGHJKLMNPQRSTVWXYZ';

String _trigram(Random rnd) {
  final pool = _consonants.split('')..shuffle(rnd);
  return pool.take(3).join();
}

MetaTask _brownPeterson(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final delay = brownPetersonDelay(req.difficulty);
  final trigram = _trigram(rnd);
  final options = <String>[trigram];
  while (options.length < 4) {
    final lure = _trigram(rnd);
    if (!options.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_peterson_prompt', {
      'tri': trigram,
      'n': delay,
    }),
    items: [trigram],
    question: trFor(locale, 'task_peterson_q'),
    options: options,
    correct: options.indexOf(trigram),
    explanation: trFor(locale, 'task_peterson_expl'),
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
  String locale,
) {
  final n = itemCountFor(req.kind, req.difficulty);
  final digits = _digits(rnd, n);
  final reversed = digits.reversed.join('-');
  final options = <String>[reversed];
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
    prompt: trFor(locale, 'task_backward_prompt'),
    items: digits,
    question: trFor(locale, 'task_backward_q'),
    options: options,
    correct: options.indexOf(reversed),
    explanation: trFor(locale, 'task_backward_expl'),
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
  String locale,
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
    for (var m = 0; m < (len > 8 ? 2 : 1); m++) {
      final at = rnd.nextInt(len);
      chars[at] = '${rnd.nextInt(10)}';
    }
    final lure = chars.join();
    if (lure != num && !options.contains(lure)) options.add(lure);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_chunk_prompt'),
    items: [num],
    question: trFor(locale, 'task_chunk_q'),
    options: options,
    correct: options.indexOf(num),
    explanation: trFor(locale, 'task_chunk_expl', {'n': len}),
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
  String locale,
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
    prompt: trFor(locale, 'task_pattern_prompt'),
    items: cells.map((c) => '$c').toList(),
    question: trFor(locale, 'task_pattern_q'),
    options: options,
    correct: options.indexOf(correct),
    explanation: trFor(locale, 'task_pattern_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _storyRecall(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = spareStoriesFor(locale);
  final s = bank[rnd.nextInt(bank.length)];
  final options = <String>[s.correct, ...s.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_story_prompt'),
    items: [s.text],
    question: s.question,
    options: options,
    correct: options.indexOf(s.correct),
    explanation: trFor(locale, 'task_story_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _categoryExemplar(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = spareCategoriesFor(locale);
  final c = bank[rnd.nextInt(bank.length)];
  final options = <String>[c.correct, ...c.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_cat_prompt'),
    items: [c.category],
    question: trFor(locale, 'task_cat_q'),
    options: options,
    correct: options.indexOf(c.correct),
    explanation: trFor(locale, 'task_cat_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _pairedAssociate(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final pool = List<String>.of(allConcreteNounsFor(locale))..shuffle(rnd);
  final cue = pool[0];
  final target = pool[1];
  final options = <String>[target];
  for (var i = 2; i < pool.length && options.length < 4; i++) {
    options.add(pool[i]);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_paired_prompt', {
      'cue': cue,
      'target': target,
    }),
    items: ['$cue → $target'],
    question: trFor(locale, 'task_paired_q', {'cue': cue}),
    options: options,
    correct: options.indexOf(target),
    explanation: trFor(locale, 'task_paired_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _faceName(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = faceNameBankFor(locale);
  final e = bank[rnd.nextInt(bank.length)];
  final options = <String>[e.name, ...e.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_face_prompt'),
    items: ['${e.feature} → ${e.name} (${e.hook})'],
    question: trFor(locale, 'task_face_q', {'feature': e.feature}),
    options: options,
    correct: options.indexOf(e.name),
    explanation: trFor(locale, 'task_face_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _keywordPair(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = foreignWordBankFor(locale);
  final e = bank[rnd.nextInt(bank.length)];
  final options = <String>[e.meaning, ...e.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_keyword_prompt', {'foreign': e.foreign}),
    items: ['${e.foreign} (${e.keyword}) → ${e.meaning}'],
    question: trFor(locale, 'task_keyword_q', {'foreign': e.foreign}),
    options: options,
    correct: options.indexOf(e.meaning),
    explanation: trFor(locale, 'task_keyword_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _prospectiveCue(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = prospectiveBankFor(locale);
  final e = bank[rnd.nextInt(bank.length)];
  final options = <String>[e.then, ...e.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_prosp_prompt'),
    items: [
      trFor(locale, 'task_prosp_item', {'when': e.when, 'then': e.then}),
    ],
    question: trFor(locale, 'task_prosp_q', {'when': e.when}),
    options: options,
    correct: options.indexOf(e.then),
    explanation: trFor(locale, 'task_prosp_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _poemChunk(
  Random rnd,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final bank = poemBankFor(locale);
  final e = bank[rnd.nextInt(bank.length)];
  final options = <String>[e.line2, ...e.lures]..shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_poem_prompt'),
    items: ['${e.line1}\n${e.line2}'],
    question: trFor(locale, 'task_poem_q', {'line': e.line1}),
    options: options,
    correct: options.indexOf(e.line2),
    explanation: trFor(locale, 'task_poem_expl'),
    paradigm: spec.id,
    source: spec.source,
    createdAt: now,
  );
}

MetaTask _dayReplay(
  Random rnd,
  MetaTaskRequest req,
  ParadigmSpec spec,
  DateTime now,
  String locale,
) {
  final n = itemCountFor(req.kind, req.difficulty);
  final pool = List<String>.of(dayEventPoolFor(locale))..shuffle(rnd);
  final day = pool.take(n).toList();
  final at = rnd.nextInt(n - 1);
  final answer = day[at + 1];
  final options = <String>[answer];
  for (final e in pool) {
    if (options.length >= 4) break;
    if (e != answer && !options.contains(e)) options.add(e);
  }
  options.shuffle(rnd);
  return MetaTask(
    prompt: trFor(locale, 'task_day_prompt'),
    items: day,
    question: trFor(locale, 'task_day_q', {'event': day[at]}),
    options: options,
    correct: options.indexOf(answer),
    explanation: trFor(locale, 'task_day_expl'),
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
