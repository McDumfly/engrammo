library;

import '../l10n/app_localizations.dart';

class TransferTarget {
  final String id;

  final String label;

  final String situation;

  final String strategy;

  final List<String> paradigms;

  final String source;

  final int track;

  const TransferTarget({
    required this.id,
    required this.label,
    required this.situation,
    required this.strategy,
    required this.paradigms,
    required this.source,
    required this.track,
  });

  String labelIn([String locale = 'en']) =>
      trFor(locale, 'transfer_${id}_label');

  String situationIn([String locale = 'en']) =>
      trFor(locale, 'transfer_${id}_situation');

  String strategyIn([String locale = 'en']) =>
      trFor(locale, 'transfer_${id}_strategy');
}

const transferTargets = <TransferTarget>[
  TransferTarget(
    id: 'exam-facts',
    label: 'Exam material',
    situation: 'Facts, definitions, and dates you must reproduce at school.',
    strategy:
        'Retrieval practice plus spaced review: test yourself, get '
        'feedback, repeat days later — never just re-read.',
    paradigms: ['paired-associate', 'category-exemplar', 'story-recall'],
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
    track: 5,
  ),
  TransferTarget(
    id: 'names',
    label: 'Names',
    situation: 'A surname you heard once and need at the next meeting.',
    strategy:
        'Attention gate first (really hear it), then a picture hook for '
        'the name, repeated back at once.',
    paradigms: ['face-name', 'paired-associate'],
    source: 'Morris et al. face-name mnemonic; MacLeod et al. (2010)',
    track: 5,
  ),
  TransferTarget(
    id: 'faces',
    label: 'Faces',
    situation: 'Linking a face you saw to the name it carries.',
    strategy:
        'Three steps, always in order: one standout feature, one image '
        'for the name, one interacting scene.',
    paradigms: ['face-name', 'picture-recall'],
    source: 'Morris et al.; McWeeny et al. (1987)',
    track: 5,
  ),
  TransferTarget(
    id: 'numbers-codes',
    label: 'Numbers and codes',
    situation: 'PINs, door codes, and short numbers worth keeping in mind.',
    strategy:
        'Chunk into groups of 3 and turn each chunk into one image; '
        'hold about 4 chunks, never 12 loose digits.',
    paradigms: ['chunk-span', 'backward-span'],
    source: 'Miller (1956); Cowan (2001)',
    track: 1,
  ),
  TransferTarget(
    id: 'years-dates',
    label: 'Years and history dates',
    situation: 'Years like 1848 or 1956 attached to events.',
    strategy:
        'One image per year, stuck onto the event cue — then recall the '
        'year from the cue, not from the page.',
    paradigms: ['chunk-span', 'paired-associate'],
    source: 'Ericsson, Chase & Faloon (1980); Karpicke & Roediger (2008)',
    track: 1,
  ),
  TransferTarget(
    id: 'birthdays',
    label: 'Birthdays',
    situation: 'Birth dates of family and friends, recalled from the name.',
    strategy:
        'Day plus month as ONE image, attached to the face cue; '
        'evening recall for a week fixes it.',
    paradigms: ['chunk-span', 'paired-associate'],
    source: 'Ericsson & Kintsch (1995)',
    track: 1,
  ),
  TransferTarget(
    id: 'deadlines',
    label: 'Deadlines',
    situation: 'Things you must do at a future moment — bills, homework.',
    strategy:
        'One if-then plan per deadline: WHEN the cue moment comes, THEN '
        'the first step. Picture the cue moment once.',
    paradigms: ['prospective-cue'],
    source: 'Gollwitzer (1999); Einstein & McDaniel (1990)',
    track: 4,
  ),
  TransferTarget(
    id: 'todos-errands',
    label: 'Todos and errands',
    situation: 'Short lists: shopping, chores, calls to make today.',
    strategy:
        'Chain the items into one silly story in order, or walk them '
        'through a tiny palace — then recall forward.',
    paradigms: ['story-recall', 'loci-drill', 'prospective-cue'],
    source: 'Craik & Tulving (1975); Dresler et al. (2017)',
    track: 4,
  ),
  TransferTarget(
    id: 'poems-verses',
    label: 'Poems to learn',
    situation: 'Verses you must recite at school or for joy.',
    strategy:
        'Two lines at a time: read, cover, recall line 2 from line 1 — '
        'retrieval between chunks, spaced over days.',
    paradigms: ['poem-chunk', 'story-recall'],
    source: 'Rubin (1995); Roediger & Karpicke (2006)',
    track: 4,
  ),
  TransferTarget(
    id: 'phone-numbers',
    label: 'Phone numbers',
    situation: 'Numbers you actually dial, without opening contacts.',
    strategy:
        'Split into groups of 3, image each group, link the images into '
        'one scene per number — morning recall for a week.',
    paradigms: ['chunk-span'],
    source: 'Miller (1956); Ericsson, Chase & Faloon (1980)',
    track: 1,
  ),
  TransferTarget(
    id: 'foreign-words',
    label: 'Foreign words',
    situation: 'Vocabulary you need for school, travel, or work.',
    strategy:
        'Keyword method: a sound-alike hook plus one interacting image '
        'per word, tested both directions with feedback.',
    paradigms: ['keyword-pair', 'paired-associate'],
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
    track: 5,
  ),
  TransferTarget(
    id: 'whole-day',
    label: 'Your whole day',
    situation: 'Everything that happened today, start to finish, in order.',
    strategy:
        'Each evening, replay the day scene by scene in order, pausing '
        'on faces, numbers, and exact words — then sleep on it.',
    paradigms: ['day-replay', 'story-recall'],
    source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
    track: 4,
  ),
];

TransferTarget? transferTargetById(String id) {
  for (final t in transferTargets) {
    if (t.id == id) return t;
  }
  return null;
}

String? huLabelForTarget(String id) => null;

String? huStrategyForTarget(String id) => null;

List<TransferTarget> transferTargetsForTrack(int track) {
  const byTrack = <int, List<String>>{
    0: ['names', 'phone-numbers', 'todos-errands'],
    1: ['numbers-codes', 'phone-numbers', 'birthdays', 'years-dates'],
    2: ['todos-errands', 'exam-facts', 'whole-day'],
    3: ['faces', 'exam-facts', 'todos-errands'],
    4: ['whole-day', 'todos-errands', 'deadlines', 'poems-verses'],
    5: ['exam-facts', 'names', 'faces', 'foreign-words'],
  };
  final ids = byTrack[track.clamp(0, 5)] ?? const <String>[];
  return [
    for (final id in ids)
      if (transferTargetById(id) != null) transferTargetById(id)!,
  ];
}

List<TransferTarget> transferTargetsForParadigm(String paradigmId) {
  return [
    for (final target in transferTargets)
      if (target.paradigms.contains(paradigmId)) target,
  ];
}
