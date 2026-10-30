library;

import '../l10n/app_localizations.dart';
import 'recall_scoring.dart' show normalizeAnswer;
import 'transfer_targets.dart' show transferTargetById;
import 'user_goals.dart' show customMaterialBlockType, isCustomGoalTarget;

class DynamicTaskResult {
  final int answered;
  final int total;
  final int correct;
  final int keyed;

  const DynamicTaskResult({
    required this.answered,
    required this.total,
    required this.correct,
    required this.keyed,
  });

  bool get complete => total > 0 && answered >= total;
}

bool dynamicTextCorrect(String expected, String response) {
  final e = expected.trim();
  final r = response.trim();
  if (e.isEmpty || r.isEmpty) return false;
  String digits(String s) => s.replaceAll(RegExp(r'\D'), '');
  if (RegExp(r'\d').hasMatch(e)) {
    return digits(e) == digits(r) && digits(r).isNotEmpty;
  }
  return normalizeAnswer(r) == normalizeAnswer(e);
}

class DynamicBlockType {
  static const info = 'info';
  static const choice = 'choice';
  static const text = 'text';
  static const date = 'date';
  static const phone = 'phone';
  static const checklist = 'checklist';
  static const order = 'order';

  static const all = <String>{
    info,
    choice,
    text,
    date,
    phone,
    checklist,
    order,
  };
}

class DynamicBlock {
  final String type;

  final String id;

  final String label;

  final String hint;

  final List<String> options;

  final String answer;

  const DynamicBlock({
    required this.type,
    required this.id,
    required this.label,
    this.hint = '',
    this.options = const [],
    this.answer = '',
  });

  DynamicBlock copyWith({
    String? type,
    String? id,
    String? label,
    String? hint,
    List<String>? options,
    String? answer,
  }) {
    return DynamicBlock(
      type: type ?? this.type,
      id: id ?? this.id,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      options: options ?? List<String>.of(this.options),
      answer: answer ?? this.answer,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'label': label,
    'hint': hint,
    'options': options,
    'answer': answer,
  };

  factory DynamicBlock.fromJson(Map<String, dynamic> json) {
    return DynamicBlock(
      type: (json['type'] as String?) ?? DynamicBlockType.info,
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      hint: (json['hint'] as String?) ?? '',
      options: [
        for (final e in (json['options'] as List? ?? const [])) e.toString(),
      ],
      answer: (json['answer'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicBlock &&
          type == other.type &&
          id == other.id &&
          label == other.label &&
          hint == other.hint &&
          answer == other.answer &&
          _listEq(options, other.options);

  @override
  int get hashCode =>
      Object.hash(type, id, label, hint, Object.hashAll(options), answer);
}

class DynamicTask {
  final String id;
  final String title;
  final String instructions;

  final String targetId;
  final List<DynamicBlock> blocks;
  final String source;
  final String model;
  final DateTime createdAt;
  final bool fallback;

  const DynamicTask({
    required this.id,
    required this.title,
    required this.instructions,
    required this.targetId,
    required this.blocks,
    this.source = '',
    this.model = 'local',
    required this.createdAt,
    this.fallback = true,
  });

  DynamicTask copyWith({
    String? id,
    String? title,
    String? instructions,
    String? targetId,
    List<DynamicBlock>? blocks,
    String? source,
    String? model,
    DateTime? createdAt,
    bool? fallback,
  }) {
    return DynamicTask(
      id: id ?? this.id,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      targetId: targetId ?? this.targetId,
      blocks: blocks ?? List<DynamicBlock>.of(this.blocks),
      source: source ?? this.source,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      fallback: fallback ?? this.fallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'instructions': instructions,
    'targetId': targetId,
    'blocks': [for (final b in blocks) b.toJson()],
    'source': source,
    'model': model,
    'createdAt': createdAt.toIso8601String(),
    'fallback': fallback,
  };

  factory DynamicTask.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return DynamicTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      instructions: (json['instructions'] as String?) ?? '',
      targetId: (json['targetId'] as String?) ?? '',
      blocks: [
        for (final e in (json['blocks'] as List? ?? const []))
          if (e is Map<String, dynamic>) DynamicBlock.fromJson(e),
      ],
      source: (json['source'] as String?) ?? '',
      model: (json['model'] as String?) ?? 'local',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      fallback: (json['fallback'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicTask &&
          id == other.id &&
          title == other.title &&
          instructions == other.instructions &&
          targetId == other.targetId &&
          source == other.source &&
          model == other.model &&
          createdAt == other.createdAt &&
          fallback == other.fallback &&
          blocks.length == other.blocks.length &&
          [for (var i = 0; i < blocks.length; i++) blocks[i] == other.blocks[i]]
              .every((e) => e);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    instructions,
    targetId,
    Object.hashAll(blocks),
    source,
    model,
    createdAt,
    fallback,
  );
}

class DynamicTaskRequest {
  final String targetId;

  final String userMaterial;

  final String forgotNote;

  final int difficulty;

  final String locale;

  final String seed;

  final String customLabel;
  final String customStrategy;
  final String customSource;

  const DynamicTaskRequest({
    required this.targetId,
    this.userMaterial = '',
    this.forgotNote = '',
    this.difficulty = 1,
    this.locale = 'en',
    this.seed = '',
    this.customLabel = '',
    this.customStrategy = '',
    this.customSource = '',
  });

  bool get isCustomGoal => isCustomGoalTarget(targetId);

  String get effectiveStrategy {
    if (isCustomGoal) {
      final s = customStrategy.trim();
      if (s.isNotEmpty) return s;
      return 'retrieval practice with feedback';
    }
    return transferTargetById(targetId)?.strategy ??
        'retrieval practice with feedback';
  }

  String get effectiveLabel {
    if (isCustomGoal) {
      final l = customLabel.trim();
      if (l.isNotEmpty) return l;
      return tr('dtask_my_goal');
    }
    return transferTargetById(targetId)?.labelIn(AppLocalizations.localeCode) ??
        tr('dtask_my_task');
  }

  String get effectiveSource {
    if (isCustomGoal) return customSource.trim();
    return transferTargetById(targetId)?.source ?? '';
  }
}

String dynamicTaskPrompt(DynamicTaskRequest req) {
  final strategy = req.effectiveStrategy;
  final material = req.userMaterial.trim().isEmpty
      ? 'No user material was given: build a generic strategy drill for '
            'this target with everyday example content.'
      : 'The user wants to remember THIS (verbatim, use it as the task '
            'content, never invent other facts to test): '
            '"${req.userMaterial.trim()}".';
  final forgot = req.forgotNote.trim().isEmpty
      ? ''
      : 'The user says they forgot THIS before: '
          '"${req.forgotNote.trim()}". Aim one block at exactly that '
          'weak spot and name the fix in its hint.';
  return 'Build ONE memory task as a single JSON object with keys '
      '"title" (short), "instructions" (2-3 sentences, direct tone), '
      '"blocks" (1-5 UI blocks). Allowed block types and their shapes: '
      '{"type":"info","label":"teaching text"}; '
      '{"type":"choice","label":"question","options":[exactly 4 different '
      'strings],"answer":"0"-"3"}; '
      '{"type":"text","label":"recall prompt","hint":"format hint",'
      '"answer":"expected text or empty for self-check"}; '
      '{"type":"date","label":"recall prompt","answer":"YYYY-MM-DD or '
      'empty"}; '
      '{"type":"phone","label":"recall prompt","answer":"digits or '
      'empty"}; '
      '{"type":"checklist","label":"do these","options":[2-5 steps]}; '
      '{"type":"order","label":"tap in order","options":[3-6 items in '
      'CORRECT order],"answer":"0,1,2…"} (the app shuffles them). '
      'Rules: 1-5 blocks, the FIRST block teaches the strategy in one '
      'sentence, at least one block must be answerable (choice/text/'
      'date/phone/order), every label non-empty, no other keys, no '
      'explanation outside the JSON. Strategy to teach: $strategy '
      '$material $forgot';
}

List<String> validateDynamicTask(DynamicTaskRequest req, DynamicTask task) {
  final bad = <String>[];
  if (task.title.trim().isEmpty) bad.add('empty title');
  if (task.instructions.trim().isEmpty) bad.add('empty instructions');
  if (task.blocks.isEmpty) bad.add('no blocks');
  if (task.blocks.length > 5) bad.add('at most 5 blocks');
  if (task.targetId != req.targetId) bad.add('target mismatch');
  var answerable = 0;
  final ids = <String>{};
  for (final b in task.blocks) {
    if (!DynamicBlockType.all.contains(b.type)) {
      bad.add('unknown block type ${b.type}');
      continue;
    }
    if (b.id.trim().isEmpty) bad.add('block without id');
    if (!ids.add(b.id)) bad.add('duplicate block id ${b.id}');
    if (b.label.trim().isEmpty) bad.add('block ${b.id} without label');
    switch (b.type) {
      case DynamicBlockType.choice:
        answerable++;
        if (b.options.length != 4) bad.add('choice ${b.id} needs 4 options');
        if (b.options.map((o) => o.trim()).toSet().length !=
            b.options.length) {
          bad.add('choice ${b.id} options must differ');
        }
        final at = int.tryParse(b.answer.trim());
        if (at == null || at < 0 || at > 3) {
          bad.add('choice ${b.id} answer must be 0-3');
        }
      case DynamicBlockType.text:
      case DynamicBlockType.date:
      case DynamicBlockType.phone:
        answerable++;
      case DynamicBlockType.order:
        answerable++;
        if (b.options.length < 3 || b.options.length > 6) {
          bad.add('order ${b.id} needs 3-6 items');
        }
        final want = List.generate(b.options.length, (i) => '$i').join(',');
        if (b.answer.trim() != want) {
          bad.add('order ${b.id} answer must list indices in order');
        }
      case DynamicBlockType.checklist:
        if (b.options.length < 2 || b.options.length > 5) {
          bad.add('checklist ${b.id} needs 2-5 steps');
        }
      case DynamicBlockType.info:
        break;
    }
  }
  if (task.blocks.isNotEmpty &&
      task.blocks.first.type != DynamicBlockType.info) {
    bad.add('first block must teach (info)');
  }
  if (answerable == 0) bad.add('need at least one answerable block');
  return bad;
}

DynamicTask localDynamicTask(DynamicTaskRequest req) {
  final title = req.effectiveLabel;
  final locale = AppLocalizations.localeCode;
  var strategy = req.effectiveStrategy;
  if (strategy == 'retrieval practice with feedback') {
    strategy = tr('dtask_strategy_test');
  } else if (!req.isCustomGoal) {
    strategy = transferTargetById(req.targetId)?.strategyIn(locale) ?? strategy;
  }
  final source = req.effectiveSource;
  final material = req.userMaterial.trim();
  final blocks = <DynamicBlock>[
    DynamicBlock(
      type: DynamicBlockType.info,
      id: 'b0',
      label: tr('dtask_strategy', {'s': strategy}),
    ),
  ];
  if (material.isNotEmpty) {
    blocks.add(
      DynamicBlock(
        type: req.isCustomGoal
            ? customMaterialBlockType(material)
            : _materialBlockType(req.targetId),
        id: 'b1',
        label: tr('dtask_cover'),
        hint: req.isCustomGoal
            ? _customMaterialHint(material)
            : _materialHint(req.targetId),
        answer: material,
      ),
    );
  } else {
    blocks.add(
      DynamicBlock(
        type: DynamicBlockType.text,
        id: 'b1',
        label: tr('dtask_write_one'),
        hint: tr('dtask_type_exact'),
      ),
    );
  }
  blocks.add(
    DynamicBlock(
      type: DynamicBlockType.checklist,
      id: 'b${blocks.length}',
      label: tr('dtask_lockin'),
      options: _lockInSteps(req.targetId),
    ),
  );
  return DynamicTask(
    id: 'local:${req.targetId}:${req.seed}',
    title: tr('dtask_mytask', {'label': title}),
    instructions: tr('dtask_instructions', {
      'extra': material.isEmpty ? tr('dtask_instructions_empty') : '',
    }),
    targetId: req.targetId,
    blocks: blocks,
    source: source,
    model: 'local',
    createdAt: DateTime.now(),
    fallback: true,
  );
}

String _materialBlockType(String targetId) {
  switch (targetId) {
    case 'birthdays':
    case 'years-dates':
      return DynamicBlockType.date;
    case 'phone-numbers':
      return DynamicBlockType.phone;
    default:
      return DynamicBlockType.text;
  }
}

String _customMaterialHint(String material) {
  switch (customMaterialBlockType(material)) {
    case DynamicBlockType.date:
      return tr('dtask_type_date');
    case DynamicBlockType.phone:
      return tr('dtask_type_digits');
    default:
      return tr('dtask_type_exact');
  }
}

String _materialHint(String targetId) {
  switch (targetId) {
    case 'birthdays':
    case 'years-dates':
      return tr('dtask_type_date');
    case 'phone-numbers':
      return tr('dtask_type_digits');
    default:
      return tr('dtask_type_exact');
  }
}

List<String> _lockInSteps(String targetId) {
  switch (targetId) {
    case 'deadlines':
    case 'todos-errands':
      return [
        tr('dtask_lock_plan_0'),
        tr('dtask_lock_plan_1'),
        tr('dtask_lock_plan_2'),
      ];
    case 'phone-numbers':
    case 'numbers-codes':
    case 'birthdays':
    case 'years-dates':
      return [
        tr('dtask_lock_recall_0'),
        tr('dtask_lock_recall_1'),
        tr('dtask_lock_recall_2'),
      ];
    case 'poems-verses':
      return [
        tr('dtask_lock_poem_0'),
        tr('dtask_lock_poem_1'),
        tr('dtask_lock_poem_2'),
      ];
    case 'whole-day':
      return [
        tr('dtask_lock_day_0'),
        tr('dtask_lock_day_1'),
        tr('dtask_lock_day_2'),
      ];
    default:
      return [
        tr('dtask_lock_default_0'),
        tr('dtask_lock_default_1'),
        tr('dtask_lock_default_2'),
      ];
  }
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
