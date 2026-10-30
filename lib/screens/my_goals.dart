import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/dynamic_task.dart';
import '../models/meta_task.dart';
import '../models/user_goals.dart';
import '../models/validated_tasks.dart' show specForId;
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/dynamic_task_view.dart';

String goalReviewHint(UserGoal goal) {
  if (goal.practiceCount <= 0) {
    return tr('myg_hint_new');
  }
  final last = goal.lastPracticedAt;
  if (last == null) return tr('myg_hint_recall');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(last.year, last.month, last.day);
  final gap = today.difference(day).inDays;
  if (gap <= 0) return tr('myg_hint_today');
  if (gap == 1) return tr('myg_hint_due_today');
  return tr('myg_hint_due_n', {'n': gap});
}

Widget _aiBadge(BuildContext context, bool fallback) {
  return Text(
    fallback ? tr('myg_ai_offline') : tr('myg_ai_built'),
    textAlign: TextAlign.center,
    style: TextStyle(
      color: context.mutedText,
      fontStyle: FontStyle.italic,
      fontSize: 12,
    ),
  );
}

class MyGoalsPage extends StatefulWidget {
  const MyGoalsPage({super.key});

  @override
  State<MyGoalsPage> createState() => _MyGoalsPageState();
}

class _MyGoalsPageState extends State<MyGoalsPage> {
  List<UserGoal> _goals = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await MemoryStore.loadUserGoals();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _loading = false;
    });
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<UserGoal>(
      MaterialPageRoute(builder: (_) => const NewGoalPage()),
    );
    if (created != null && mounted) _load();
  }

  Future<void> _openGoal(UserGoal goal) async {
    AppFeedback.light();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: goal.id)),
    );
    if (mounted) _load();
  }

  Future<void> _deleteGoal(UserGoal goal) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('myg_delete_title'),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          tr('myg_delete_body', {'title': goal.title}),
          style: TextStyle(color: context.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('myg_keep')),
          ),
          FilledButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('myg_delete')),
          ),
        ],
      ),
    );
    if (yes == true) {
      await MemoryStore.deleteUserGoal(goal.id);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: EngramBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr('myg_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          AiHelpButton(topic: AiHelpTopics.goals),
          SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const ValueKey('goals-list'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  _goals.isEmpty
                      ? tr('myg_intro_empty')
                      : _goals.length == 1
                      ? tr('myg_intro_one')
                      : tr('myg_intro_many', {'n': _goals.length}),
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                EngramButton(
                  key: const ValueKey('goals-new'),
                  label: tr('myg_new_goal_btn'),
                  icon: HugeIcons.strokeRoundedPencilEdit02,
                  onPressed: _openNew,
                ),
                const SizedBox(height: 12),
                if (_goals.isEmpty) _emptyCard() else ...[
                  for (final goal in _goals) ...[
                    _goalCard(goal),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedTarget01,
                color: Color(0xFF45A3FF),
                size: 22,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 8),
              Text(
                tr('myg_examples'),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('myg_examples_body'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(UserGoal goal) {
    final analysis = goal.analysis;
    return GestureDetector(
      key: ValueKey('goals-open-${goal.id}'),
      onTap: () => _openGoal(goal),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.faintBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  key: ValueKey('goals-delete-${goal.id}'),
                  onTap: () => _deleteGoal(goal),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
                      color: Color(0xFFFF6B6B),
                      size: 20,
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
              ],
            ),
            if (analysis != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(goalTrackName(analysis.track)),
                  for (final p in analysis.paradigms.take(2))
                    _chip(specForId(p).displayName),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  color: Color(0xFF45A3FF),
                  size: 16,
                  strokeWidth: 2.2,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    goalReviewHint(goal),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '×${goal.practiceCount}',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.washBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF45A3FF),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class NewGoalPage extends StatefulWidget {
  const NewGoalPage({super.key});

  @override
  State<NewGoalPage> createState() => _NewGoalPageState();
}

class _NewGoalPageState extends State<NewGoalPage> {
  final _titleCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  GoalAnalysis? _analysis;
  bool _analysisFallback = true;
  bool _analyzing = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _detailsCtrl.dispose();
    _materialCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty && !_analyzing && !_saving;

  Future<void> _analyze() async {
    if (_titleCtrl.text.trim().isEmpty || _analyzing) return;
    setState(() {
      _analyzing = true;
      _analysis = null;
    });
    final answer = await MetaAIService.analyzeGoal(
      title: _titleCtrl.text,
      details: _detailsCtrl.text,
      material: _materialCtrl.text,
      locale: AppLocalizations.localeCode,
    );
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _analysis = answer.analysis;
      _analysisFallback = answer.fallback;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final analysis =
        _analysis ??
        localGoalAnalysis(
          title: title,
          details: _detailsCtrl.text,
          material: _materialCtrl.text,
          locale: AppLocalizations.localeCode,
        );
    final now = DateTime.now();
    final goal = UserGoal(
      id: newGoalId(now),
      title: title,
      details: _detailsCtrl.text.trim(),
      material: _materialCtrl.text.trim(),
      createdAt: now,
      updatedAt: now,
      analysis: analysis,
    );
    await MemoryStore.addUserGoal(goal);
    if (!mounted) return;
    AppFeedback.medium();
    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: EngramBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr('myg_new_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          AiHelpButton(topic: AiHelpTopics.goals),
          SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            tr('myg_new_blurb'),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('goal-title-input'),
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr('myg_label_title'),
              hintText: tr('myg_hint_title'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: context.inkText, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('goal-details-input'),
            controller: _detailsCtrl,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              labelText: tr('myg_label_details'),
              hintText: tr('myg_hint_details'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: context.inkText, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('goal-material-input'),
            controller: _materialCtrl,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              labelText: tr('myg_label_material'),
              hintText: tr('myg_hint_material'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: context.inkText, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('goal-analyze-button'),
            onPressed: _titleCtrl.text.trim().isEmpty || _analyzing
                ? null
                : _analyze,
            child: Text(tr('myg_analyze')),
          ),
          if (_analyzing) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              key: const ValueKey('goal-analyze-progress'),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 4),
            Text(
              tr('myg_analyzing'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 12),
            _GoalAnalysisCard(
              analysis: _analysis!,
              fallback: _analysisFallback,
            ),
          ],
          const SizedBox(height: 16),
          EngramButton(
            key: const ValueKey('goal-save-button'),
            label: tr('myg_save'),
            onPressed: _canSave ? _save : null,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}

class _GoalAnalysisCard extends StatelessWidget {
  final GoalAnalysis analysis;
  final bool fallback;
  const _GoalAnalysisCard({required this.analysis, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('goal-analysis-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.washBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAiChat02,
                color: Color(0xFF45A3FF),
                size: 20,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${goalTrackName(analysis.track)} · '
                  '${analysis.paradigms.map(specForId).map((s) => s.displayName).join(' + ')}',
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.strategy,
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < analysis.plan.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ',
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      analysis.plan[i],
                      style: TextStyle(
                        color: context.inkText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (analysis.source.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              analysis.source,
              style: TextStyle(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _aiBadge(context, fallback),
        ],
      ),
    );
  }
}

class GoalDetailPage extends StatefulWidget {
  final String goalId;
  const GoalDetailPage({super.key, required this.goalId});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  UserGoal? _goal;
  bool _loading = true;

  final _materialCtrl = TextEditingController();
  bool _savingMaterial = false;

  final _forgotCtrl = TextEditingController();
  String? _busy;
  String _teacherText = '';
  bool _teacherFallback = true;
  String _diagnoseText = '';
  bool _diagnoseFallback = true;

  DynamicTask? _dynamic;
  MetaTask? _drill;
  int? _drillPicked;
  int _drillRound = 0;

  final Set<int> _planDone = {};

  @override
  void initState() {
    super.initState();
    _materialCtrl.addListener(_onMaterialChanged);
    _load();
  }

  @override
  void dispose() {
    _materialCtrl.dispose();
    _forgotCtrl.dispose();
    super.dispose();
  }

  void _onMaterialChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final goal = await MemoryStore.loadUserGoal(widget.goalId);
    if (!mounted) return;
    if (goal == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _goal = goal;
      _loading = false;
      if (_materialCtrl.text.isEmpty) _materialCtrl.text = goal.material;
      if (_forgotCtrl.text.isEmpty) _forgotCtrl.text = goal.forgotNote;
    });
  }

  GoalAnalysis get _analysis =>
      _goal?.analysis ??
      localGoalAnalysis(title: _goal?.title ?? '', material: '');

  String get _strategy => _analysis.strategy;
  String get _label => _goal?.title ?? 'My goal';
  String get _source => _analysis.source;
  String get _material =>
      _materialCtrl.text.trim().isNotEmpty ? _materialCtrl.text.trim() : '';

  Future<void> _recordPractice() async {
    final updated = await MemoryStore.recordGoalPractice(widget.goalId);
    if (updated != null && mounted) {
      setState(() => _goal = updated);
    } else {
      unawaited(_load());
    }
  }

  Future<void> _saveMaterial() async {
    final goal = _goal;
    if (goal == null || _savingMaterial) return;
    setState(() => _savingMaterial = true);
    final now = DateTime.now();
    final next = goal.copyWith(
      material: _materialCtrl.text.trim(),
      updatedAt: now,
    );
    await MemoryStore.updateUserGoal(next);
    if (!mounted) return;
    setState(() {
      _goal = next;
      _savingMaterial = false;
    });
    AppFeedback.medium();
  }

  Future<void> _reanalyze() async {
    final goal = _goal;
    if (goal == null || _busy != null) return;
    setState(() => _busy = 'reanalyze');
    final answer = await MetaAIService.analyzeGoal(
      title: goal.title,
      details: goal.details,
      material: _materialCtrl.text,
      locale: AppLocalizations.localeCode,
    );
    if (!mounted) return;
    final now = DateTime.now();
    final next = goal.copyWith(
      material: _materialCtrl.text.trim(),
      updatedAt: now,
      analysis: answer.analysis,
    );
    await MemoryStore.updateUserGoal(next);
    if (!mounted) return;
    setState(() {
      _goal = next;
      _busy = null;
      _planDone.clear();
    });
    AppFeedback.medium();
  }

  Future<void> _runTeach() async {
    final goal = _goal;
    if (goal == null || _busy != null) return;
    setState(() {
      _busy = 'teach';
      _teacherText = '';
    });
    final answer = await MetaAIService.explainTechnique(
      targetId: goal.id,
      userMaterial: _material,
      forgotNote: _forgotCtrl.text,
      locale: AppLocalizations.localeCode,
      customLabel: _label,
      customStrategy: _strategy,
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      _teacherText = answer.text;
      _teacherFallback = answer.fallback;
    });
  }

  Future<void> _runDiagnose() async {
    final goal = _goal;
    if (goal == null ||
        _busy != null ||
        _forgotCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = 'diagnose';
      _diagnoseText = '';
    });
    final answer = await MetaAIService.diagnoseForgetting(
      targetId: goal.id,
      forgotNote: _forgotCtrl.text,
      locale: AppLocalizations.localeCode,
      customLabel: _label,
      customStrategy: _strategy,
    );
    if (!mounted) return;
    unawaited(
      MemoryStore.updateUserGoal(
        goal.copyWith(
          forgotNote: _forgotCtrl.text.trim(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
    setState(() {
      _busy = null;
      _diagnoseText = answer.text;
      _diagnoseFallback = answer.fallback;
    });
  }

  Future<void> _runBuild() async {
    final goal = _goal;
    if (goal == null || _busy != null) return;
    setState(() {
      _busy = 'build';
      _dynamic = null;
    });
    unawaited(
      MemoryStore.updateUserGoal(
        goal.copyWith(
          material: _materialCtrl.text.trim(),
          forgotNote: _forgotCtrl.text.trim(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
    final task = await MetaAIService.buildDynamicTask(
      DynamicTaskRequest(
        targetId: goal.id,
        customLabel: _label,
        customStrategy: _strategy,
        customSource: _source,
        userMaterial: _material,
        forgotNote: _forgotCtrl.text,
        difficulty: _analysis.difficulty,
        locale: AppLocalizations.localeCode,
        seed: 'goal:${goal.id}:${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      _dynamic = task;
    });
  }

  Future<void> _runDrill() async {
    final goal = _goal;
    if (goal == null || _busy != null) return;
    setState(() {
      _busy = 'drill';
      _drill = null;
      _drillPicked = null;
    });
    final kinds = goalKindsFor(_analysis);
    final kind = kinds[_drillRound % kinds.length];
    final task = await MetaAIService.generateTask(
      MetaTaskRequest(
        kind: kind,
        difficulty: _analysis.difficulty,
        seed: 'goal:${goal.id}:drill:$_drillRound:'
            '${DateTime.now().millisecondsSinceEpoch}',
        locale: AppLocalizations.localeCode,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      _drill = task;
    });
  }

  void _answerDrill(int option) {
    if (_drill == null || _drillPicked != null) return;
    setState(() => _drillPicked = option);
    if (option == _drill!.correct) {
      AppFeedback.medium();
    } else {
      AppFeedback.heavy();
    }
    unawaited(_recordPractice());
  }

  void _nextDrill() {
    setState(() => _drillRound++);
    _runDrill();
  }

  Future<void> _delete() async {
    final goal = _goal;
    if (goal == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('myg_delete_title'),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          tr('myg_delete_body', {'title': goal.title}),
          style: TextStyle(color: context.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('myg_keep')),
          ),
          FilledButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('myg_delete')),
          ),
        ],
      ),
    );
    if (yes == true) {
      await MemoryStore.deleteUserGoal(goal.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: EngramBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          goal?.title ?? tr('myg_goal_fallback'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          AiHelpButton(
            topic: AiHelpTopics.goals,
            helpContext: goal == null ? '' : 'Goal: ${goal.title}',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading || goal == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _headerCard(goal),
                const SizedBox(height: 12),
                _planCard(),
                const SizedBox(height: 12),
                _materialCard(goal),
                const SizedBox(height: 12),
                _teachCard(),
                const SizedBox(height: 12),
                _diagnoseCard(),
                const SizedBox(height: 12),
                _buildCard(),
                const SizedBox(height: 12),
                _drillCard(),
                const SizedBox(height: 16),
                TextButton(
                  key: const ValueKey('goal-delete-button'),
                  onPressed: _busy == null ? _delete : null,
                  child: Text(tr('myg_delete_this')),
                ),
              ],
            ),
    );
  }

  Widget _headerCard(UserGoal goal) {
    final analysis = _analysis;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.washBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.washBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goal.details.trim().isNotEmpty)
            Text(
              goal.details.trim(),
              style: TextStyle(
                color: context.inkText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip(goalTrackName(analysis.track)),
              for (final p in analysis.paradigms)
                _miniChip(specForId(p).displayName),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.strategy,
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (analysis.source.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              analysis.source,
              style: TextStyle(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                color: Color(0xFF45A3FF),
                size: 16,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${goalReviewHint(goal)} · ×${goal.practiceCount}',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('goal-reanalyze-button'),
                onTap: _busy == null ? _reanalyze : null,
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      color: Color(0xFF45A3FF),
                      size: 16,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr('myg_reanalyze'),
                      style: TextStyle(
                        color: _busy == null
                            ? const Color(0xFF45A3FF)
                            : context.mutedText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy == 'reanalyze') ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: const ValueKey('goal-reanalyze-progress'),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.faintBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.inkText,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String keyName,
    required List<List<dynamic>> icon,
    required String title,
    required String blurb,
    required List<Widget> children,
  }) {
    return Container(
      key: ValueKey(keyName),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: icon,
                color: const Color(0xFF45A3FF),
                size: 20,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            blurb,
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _aiProgress(String keyName, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        LinearProgressIndicator(
          key: ValueKey(keyName),
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _planCard() {
    final plan = _analysis.plan;
    return _sectionCard(
      keyName: 'goal-plan',
      icon: HugeIcons.strokeRoundedRoute01,
      title: tr('myg_plan_title'),
      blurb: tr('myg_plan_blurb'),
      children: [
        for (var i = 0; i < plan.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              key: ValueKey('goal-plan-step-$i'),
              onTap: () {
                AppFeedback.light();
                setState(() {
                  if (!_planDone.add(i)) _planDone.remove(i);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _planDone.contains(i)
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.12)
                      : context.washBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _planDone.contains(i)
                        ? const Color(0xFF14B8A6)
                        : context.faintBorder,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: _planDone.contains(i)
                          ? HugeIcons.strokeRoundedCheckmarkCircle02
                          : HugeIcons.strokeRoundedCircle,
                      color: _planDone.contains(i)
                          ? const Color(0xFF14B8A6)
                          : context.mutedText,
                      size: 20,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plan[i],
                        style: TextStyle(
                          color: context.inkText,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _materialCard(UserGoal goal) {
    final dirty = _materialCtrl.text.trim() != goal.material.trim();
    return _sectionCard(
      keyName: 'goal-material',
      icon: HugeIcons.strokeRoundedNote01,
      title: tr('myg_material_title'),
      blurb: tr('myg_material_blurb'),
      children: [
        TextField(
          key: const ValueKey('goal-detail-material-input'),
          controller: _materialCtrl,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            hintText: tr('myg_hint_material'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: TextStyle(color: context.inkText, fontSize: 14),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('goal-material-save'),
          onPressed: dirty && !_savingMaterial && _busy == null
              ? _saveMaterial
              : null,
          child: Text(
            _savingMaterial ? tr('myg_saving') : tr('myg_save_material'),
          ),
        ),
      ],
    );
  }

  Widget _teachCard() {
    return _sectionCard(
      keyName: 'goal-teach',
      icon: HugeIcons.strokeRoundedIdea01,
      title: tr('myg_teach_title'),
      blurb: tr('myg_teach_blurb'),
      children: [
        OutlinedButton(
          key: const ValueKey('goal-teach-button'),
          onPressed: _busy == null ? _runTeach : null,
          child: Text(tr('myg_teach_btn')),
        ),
        if (_busy == 'teach') _aiProgress(
          'goal-teach-progress',
          tr('myg_teach_busy'),
        ),
        if (_teacherText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _teacherText,
            key: const ValueKey('goal-teach-result'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          _aiBadge(context, _teacherFallback),
        ],
      ],
    );
  }

  Widget _diagnoseCard() {
    return _sectionCard(
      keyName: 'goal-diagnose',
      icon: HugeIcons.strokeRoundedAiChat02,
      title: tr('myg_diag_title'),
      blurb: tr('myg_diag_blurb'),
      children: [
        TextField(
          key: const ValueKey('goal-forgot-input'),
          controller: _forgotCtrl,
          maxLines: 2,
          minLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('myg_diag_label'),
            hintText: tr('myg_diag_hint'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: TextStyle(color: context.inkText, fontSize: 14),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('goal-diagnose-button'),
          onPressed:
              _busy == null && _forgotCtrl.text.trim().isNotEmpty
              ? _runDiagnose
              : null,
          child: Text(tr('myg_diag_btn')),
        ),
        if (_busy == 'diagnose') _aiProgress(
          'goal-diagnose-progress',
          tr('myg_diag_busy'),
        ),
        if (_diagnoseText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _diagnoseText,
            key: const ValueKey('goal-diagnose-result'),
            style: TextStyle(
              color: context.inkText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          _aiBadge(context, _diagnoseFallback),
        ],
      ],
    );
  }

  Widget _buildCard() {
    return _sectionCard(
      keyName: 'goal-build',
      icon: HugeIcons.strokeRoundedPuzzle,
      title: tr('myg_build_title'),
      blurb: tr('myg_build_blurb'),
      children: [
        FilledButton(
          key: const ValueKey('goal-build-button'),
          onPressed: _busy == null ? _runBuild : null,
          child: Text(tr('myg_build_btn')),
        ),
        if (_busy == 'build') _aiProgress(
          'goal-build-progress',
          tr('myg_build_busy'),
        ),
        if (_dynamic != null) ...[
          const SizedBox(height: 12),
          DynamicTaskView(
            key: const ValueKey('goal-dynamic-task'),
            task: _dynamic!,
            onDone: (_) => _recordPractice(),
          ),
        ],
      ],
    );
  }

  Widget _drillCard() {
    return _sectionCard(
      keyName: 'goal-drill',
      icon: HugeIcons.strokeRoundedDumbbell01,
      title: tr('myg_drill_title'),
      blurb: tr('myg_drill_blurb'),
      children: [
        if (_drill == null && _busy != 'drill')
          OutlinedButton(
            key: const ValueKey('goal-drill-button'),
            onPressed: _busy == null ? _runDrill : null,
            child: Text(tr('myg_drill_btn')),
          ),
        if (_busy == 'drill') _aiProgress(
          'goal-drill-progress',
          tr('myg_drill_busy'),
        ),
        if (_drill != null) _drillBody(_drill!),
      ],
    );
  }

  Widget _drillBody(MetaTask drill) {
    final spec = specForId(drill.paradigm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('myg_drill_round', {
            'name': spec.displayName,
            'n': _drillRound + 1,
          }),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          drill.prompt,
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in drill.items)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.washBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.washBorder),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          drill.question,
          style: TextStyle(
            color: context.inkText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < drill.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              key: ValueKey('goal-drill-option-$i'),
              onTap: _drillPicked == null ? () => _answerDrill(i) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _drillPicked != null && i == drill.correct
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.14)
                      : _drillPicked != null && i == _drillPicked
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                      : context.washBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.faintBorder),
                ),
                child: Text(
                  drill.options[i],
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        if (_drillPicked != null) ...[
          const SizedBox(height: 4),
          Text(
            _drillPicked == drill.correct
                ? tr('myg_drill_correct')
                : tr('myg_drill_wrong', {
                    'answer': drill.options[drill.correct],
                  }),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (drill.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              drill.explanation.trim(),
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('goal-drill-next'),
            onPressed: _busy == null ? _nextDrill : null,
            child: Text(tr('myg_drill_next')),
          ),
        ],
        const SizedBox(height: 4),
        _aiBadge(context, drill.fallback),
      ],
    );
  }
}
