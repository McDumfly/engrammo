library;

import 'dart:convert' show jsonDecode;

import '../l10n/app_localizations.dart';
import 'transfer_targets.dart'
    show TransferTarget, transferTargetById;

const goalIdPrefix = 'goal-';

const customTargetPrefixes = ['goal-', 'goal:', 'custom:'];

bool isCustomGoalTarget(String targetId) {
  for (final p in customTargetPrefixes) {
    if (targetId.startsWith(p)) return true;
  }
  return false;
}

var _goalCounter = 0;

String newGoalId([DateTime? now]) {
  final micros = (now ?? DateTime.now()).microsecondsSinceEpoch;
  final seq = (_goalCounter++).toRadixString(36);
  return '$goalIdPrefix$micros-$seq';
}

const goalTrackNames = <String>[
  'Sensory',
  'Working memory',
  'Spatial',
  'Visual',
  'Episodic',
  'Semantic',
];

String goalTrackName(int track) =>
    tr('track_${track.clamp(0, goalTrackNames.length - 1)}_name');

const allowedGoalParadigms = <String>{
  'backward-span',
  'iconic-probe',
  'echoic-probe',
  'brown-peterson',
  'chunk-span',
  'loci-drill',
  'picture-recall',
  'pattern-span',
  'story-recall',
  'category-exemplar',
  'paired-associate',
  'face-name',
  'keyword-pair',
  'prospective-cue',
  'poem-chunk',
  'day-replay',
};

String paradigmToKind(String paradigmId) {
  switch (paradigmId) {
    case 'backward-span':
      return 'sequence';
    case 'brown-peterson':
      return 'interference';
    case 'chunk-span':
      return 'number';
    case 'loci-drill':
      return 'spatial';
    case 'picture-recall':
      return 'visual';
    case 'pattern-span':
      return 'pattern';
    case 'story-recall':
      return 'episodic';
    case 'category-exemplar':
      return 'semantic';
    case 'paired-associate':
      return 'verbal';
    case 'face-name':
      return 'face';
    case 'keyword-pair':
      return 'foreign';
    case 'prospective-cue':
      return 'prospective';
    case 'poem-chunk':
      return 'poem';
    case 'day-replay':
      return 'replay';
    case 'iconic-probe':
    case 'echoic-probe':
    default:
      return 'sensory';
  }
}

List<String> goalKindsFor(GoalAnalysis analysis) {
  final kinds = <String>[];
  for (final p in analysis.paradigms) {
    final k = paradigmToKind(p);
    if (!kinds.contains(k)) kinds.add(k);
  }
  return kinds.isEmpty ? ['verbal'] : kinds;
}

class GoalAnalysis {
  final int track;

  final String strategy;

  final List<String> paradigms;

  final String source;

  final List<String> plan;

  final int difficulty;

  const GoalAnalysis({
    required this.track,
    required this.strategy,
    required this.paradigms,
    required this.source,
    required this.plan,
    this.difficulty = 1,
  });

  GoalAnalysis copyWith({
    int? track,
    String? strategy,
    List<String>? paradigms,
    String? source,
    List<String>? plan,
    int? difficulty,
  }) {
    return GoalAnalysis(
      track: track ?? this.track,
      strategy: strategy ?? this.strategy,
      paradigms: paradigms ?? List<String>.of(this.paradigms),
      source: source ?? this.source,
      plan: plan ?? List<String>.of(this.plan),
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, dynamic> toJson() => {
    'track': track,
    'strategy': strategy,
    'paradigms': paradigms,
    'source': source,
    'plan': plan,
    'difficulty': difficulty,
  };

  factory GoalAnalysis.fromJson(Map<String, dynamic> json) {
    return GoalAnalysis(
      track: (json['track'] as num?)?.toInt() ?? 5,
      strategy: (json['strategy'] as String?) ?? '',
      paradigms: [
        for (final e in (json['paradigms'] as List? ?? const [])) e.toString(),
      ],
      source: (json['source'] as String?) ?? '',
      plan: [for (final e in (json['plan'] as List? ?? const [])) e.toString()],
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAnalysis &&
          track == other.track &&
          strategy == other.strategy &&
          source == other.source &&
          difficulty == other.difficulty &&
          _listEq(paradigms, other.paradigms) &&
          _listEq(plan, other.plan);

  @override
  int get hashCode => Object.hash(
    track,
    strategy,
    Object.hashAll(paradigms),
    source,
    Object.hashAll(plan),
    difficulty,
  );
}

class UserGoal {
  final String id;

  final String title;

  final String details;

  final String material;

  final String forgotNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  final GoalAnalysis? analysis;

  final int practiceCount;

  final DateTime? lastPracticedAt;

  const UserGoal({
    required this.id,
    required this.title,
    this.details = '',
    this.material = '',
    this.forgotNote = '',
    required this.createdAt,
    required this.updatedAt,
    this.analysis,
    this.practiceCount = 0,
    this.lastPracticedAt,
  });

  factory UserGoal.fresh({
    required String title,
    String details = '',
    String material = '',
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return UserGoal(
      id: newGoalId(at),
      title: title,
      details: details,
      material: material,
      createdAt: at,
      updatedAt: at,
    );
  }

  UserGoal copyWith({
    String? id,
    String? title,
    String? details,
    String? material,
    String? forgotNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    GoalAnalysis? analysis,
    bool clearAnalysis = false,
    int? practiceCount,
    DateTime? lastPracticedAt,
    bool clearPracticedAt = false,
  }) {
    return UserGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      material: material ?? this.material,
      forgotNote: forgotNote ?? this.forgotNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      practiceCount: practiceCount ?? this.practiceCount,
      lastPracticedAt: clearPracticedAt
          ? null
          : (lastPracticedAt ?? this.lastPracticedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'details': details,
    'material': material,
    'forgotNote': forgotNote,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'analysis': analysis?.toJson(),
    'practiceCount': practiceCount,
    'lastPracticedAt': lastPracticedAt?.toIso8601String(),
  };

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final updated =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created;
    final practiced = json['lastPracticedAt'] is String
        ? DateTime.tryParse(json['lastPracticedAt'] as String)
        : null;
    final rawAnalysis = json['analysis'];
    return UserGoal(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      details: (json['details'] as String?) ?? '',
      material: (json['material'] as String?) ?? '',
      forgotNote: (json['forgotNote'] as String?) ?? '',
      createdAt: created,
      updatedAt: updated,
      analysis: rawAnalysis is Map<String, dynamic>
          ? GoalAnalysis.fromJson(rawAnalysis)
          : null,
      practiceCount: (json['practiceCount'] as num?)?.toInt() ?? 0,
      lastPracticedAt: practiced,
    );
  }
}

class _GoalPreset {
  final String targetId;
  final List<String> keys;
  const _GoalPreset(this.targetId, this.keys);
}

const _goalPresets = <_GoalPreset>[
  _GoalPreset(
    'phone-numbers',
    [
      'phone',
      'mobile',
      '+36',
      '+1',
      '+49',
      'contact',
    ],
  ),
  _GoalPreset(
    'numbers-codes',
    [
      ' pin ',
      'pin-',
      'pin:',
      'door code',
      'password',
      'digits',
      'number',
      'otp',
      'cvc',
    ],
  ),
  _GoalPreset(
    'birthdays',
    [
      'birthday',
      'born',
      'anniversary',
    ],
  ),
  _GoalPreset(
    'years-dates',
    [
      'year',
      'history',
      'revolution',
    ],
  ),
  _GoalPreset(
    'names',
    [
      'name',
      'names',
      'surname',
      'introduction',
      'colleague',
      'client',
    ],
  ),
  _GoalPreset(
    'faces',
    [
      'face',
      'faces',
      'facial',
      'recogniz',
    ],
  ),
  _GoalPreset(
    'deadlines',
    [
      'deadline',
      'bills',
      ' bill ',
      'appointment',
      'doctor',
      'remember to',
    ],
  ),
  _GoalPreset(
    'todos-errands',
    [
      'todo',
      'shopping',
      'grocery',
      'lists',
      'list of',
      'my list',
      'chores',
      'errand',
      'recipe',
      'ingredients',
      'packing',
      'daily tasks',
    ],
  ),
  _GoalPreset(
    'poems-verses',
    [
      'poem',
      'poetry',
      'stanza',
      'recit',
    ],
  ),
  _GoalPreset(
    'foreign-words',
    [
      'english',
      'german',
      'french',
      'spanish',
      'italian',
      'words',
      'vocabulary',
      'language',
      'phrase',
      'synonym',
    ],
  ),
  _GoalPreset(
    'exam-facts',
    [
      'exam',
      'tests',
      ' test ',
      'concept',
      'textbook',
      'university',
      'school',
      'learn',
      'formula',
    ],
  ),
  _GoalPreset(
    'whole-day',
    [
      'whole day',
      'what happened',
      'happened',
      'meeting',
      'journal',
      'diary',
      'replay the day',
    ],
  ),
];

GoalAnalysis _defaultAnalysis(int difficulty, [String locale = 'en']) {
  final base = GoalAnalysis(
    track: 5,
    strategy: trFor(locale, 'goal_default_strategy'),
    paradigms: const ['paired-associate', 'story-recall'],
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
    plan: [
      trFor(locale, 'goal_default_plan_0'),
      trFor(locale, 'goal_default_plan_1'),
      trFor(locale, 'goal_default_plan_2'),
    ],
    difficulty: 1,
  );
  return base.copyWith(difficulty: difficulty);
}

int goalDifficultyFor(String material) {
  final n = material.trim().length;
  if (n >= 120) return 3;
  if (n >= 30) return 2;
  return 1;
}

GoalAnalysis localGoalAnalysis({
  required String title,
  String details = '',
  String material = '',
  String locale = 'en',
}) {
  final difficulty = goalDifficultyFor(material);
  final padded = ' ${'$title\n$details\n$material'.toLowerCase()} ';
  for (final preset in _goalPresets) {
    for (final key in preset.keys) {
      if (padded.contains(key)) {
        final target = transferTargetById(preset.targetId);
        if (target == null) break;
        return GoalAnalysis(
          track: target.track,
          strategy: target.strategyIn(locale),
          paradigms: List<String>.of(target.paradigms),
          source: target.source,
          plan: [
            for (var i = 0; i < 3; i++)
              trFor(locale, 'goal_plan_${preset.targetId}_$i'),
          ],
          difficulty: difficulty,
        );
      }
    }
  }
  return _defaultAnalysis(difficulty, locale);
}

TransferTarget? nearestTransferTarget(GoalAnalysis analysis) {
  TransferTarget? best;
  var bestScore = -1;
  for (final t in _allTargets()) {
    var score = 0;
    for (final p in analysis.paradigms) {
      if (t.paradigms.contains(p)) score += 2;
    }
    if (t.track == analysis.track) score += 1;
    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return best;
}

List<TransferTarget> _allTargets() {
  const ids = [
    'exam-facts',
    'names',
    'faces',
    'numbers-codes',
    'years-dates',
    'birthdays',
    'deadlines',
    'todos-errands',
    'poems-verses',
    'phone-numbers',
    'foreign-words',
    'whole-day',
  ];
  return [for (final id in ids) transferTargetById(id)!];
}

String goalAnalysisPrompt({
  required String title,
  String details = '',
  String material = '',
  String locale = 'en',
}) {
  final ids = allowedGoalParadigms
      .where((p) => p != 'echoic-probe')
      .join(', ');
  final context = [
    if (title.trim().isNotEmpty) 'Wish: "${title.trim()}".',
    if (details.trim().isNotEmpty) 'Context: "${details.trim()}".',
    if (material.trim().isNotEmpty)
      'Material (verbatim, do NOT test other facts): "${material.trim()}".'
    else
      'No material given yet.',
  ].join(' ');
  return 'Classify ONE memory wish onto fixed scientific rails and return '
      'a single JSON object with keys "track" (memory-track index 0-5: '
      '0 sensory hearing, 1 working-memory numbers, 2 spatial palaces, '
      '3 visual imagery, 4 episodic stories and plans, 5 semantic facts '
      'and words), "strategy" (1-2 sentences, the fixed procedure), '
      '"paradigms" (1-3 ids from this list only: $ids), "source" (one '
      'study citation), "plan" (2-6 concrete review steps as strings), '
      '"difficulty" (1-5). Rules: paradigms ONLY from the list, no other '
      'keys, no explanation outside the JSON. Never diagnose, never '
      'promise grades, IQ gains, or job performance. $context';
}

List<String> validateGoalAnalysis(GoalAnalysis analysis) {
  final bad = <String>[];
  if (analysis.track < 0 || analysis.track > 5) {
    bad.add('track must be 0-5');
  }
  if (analysis.strategy.trim().isEmpty) bad.add('empty strategy');
  if (analysis.paradigms.isEmpty) bad.add('no paradigms');
  if (analysis.paradigms.length > 3) bad.add('at most 3 paradigms');
  for (final p in analysis.paradigms) {
    if (!allowedGoalParadigms.contains(p)) bad.add('unknown paradigm $p');
  }
  if (analysis.paradigms.toSet().length != analysis.paradigms.length) {
    bad.add('paradigms must differ');
  }
  if (analysis.plan.length < 2) bad.add('plan needs 2-6 steps');
  if (analysis.plan.length > 6) bad.add('plan needs 2-6 steps');
  if (analysis.plan.any((s) => s.trim().isEmpty)) {
    bad.add('empty plan step');
  }
  if (analysis.difficulty < 1 || analysis.difficulty > 5) {
    bad.add('difficulty must be 1-5');
  }
  return bad;
}

GoalAnalysis? parseGoalAnalysisContent(String content) {
  try {
    var text = content.trim();
    if (text.startsWith('```')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      text = text.substring(start, end + 1);
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final data = _decodeJson(text.substring(start, end + 1));
    if (data == null) return null;
    final track = (data['track'] as num?)?.toInt();
    if (track == null || track < 0 || track > 5) return null;
    final strategy = ((data['strategy'] as String?) ?? '').trim();
    if (strategy.isEmpty) return null;
    final rawParadigms = data['paradigms'];
    if (rawParadigms is! List || rawParadigms.isEmpty) return null;
    final paradigms = <String>[];
    for (final e in rawParadigms) {
      var p = e.toString().trim();
      if (p == 'echoic-probe') p = 'iconic-probe';
      if (!allowedGoalParadigms.contains(p)) return null;
      if (!paradigms.contains(p)) paradigms.add(p);
    }
    if (paradigms.isEmpty || paradigms.length > 3) return null;
    final rawPlan = data['plan'];
    if (rawPlan is! List) return null;
    final plan = [
      for (final e in rawPlan)
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
    if (plan.length < 2) return null;
    final cappedPlan = plan.length > 6 ? plan.sublist(0, 6) : plan;
    final source = ((data['source'] as String?) ?? '').trim();
    final difficulty = (data['difficulty'] as num?)?.toInt() ?? 1;
    final candidate = GoalAnalysis(
      track: track,
      strategy: strategy.length > 500
          ? strategy.substring(0, 500)
          : strategy,
      paradigms: paradigms,
      source: source.isEmpty ? 'Dunlosky et al. (2013)' : source,
      plan: [
        for (final s in cappedPlan)
          s.length > 200 ? s.substring(0, 200) : s,
      ],
      difficulty: difficulty.clamp(1, 5),
    );
    if (validateGoalAnalysis(candidate).isNotEmpty) return null;
    return candidate;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _decodeJson(String text) {
  try {
    final data = jsonDecode(text);
    if (data is Map<String, dynamic>) return data;
    return null;
  } catch (_) {
    return null;
  }
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String customMaterialBlockType(String material) {
  final digits = material.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 7) return 'phone';
  final lower = material.toLowerCase();
  const dateHints = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
    'january',
    'february',
    'march',
    'april',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  final dashed = RegExp(r'\d{2,4}[.\-/]\d{1,2}([.\-/]\d{1,4})?');
  if (dashed.hasMatch(material)) return 'date';
  for (final h in dateHints) {
    if (lower.contains(h)) return 'date';
  }
  return 'text';
}
