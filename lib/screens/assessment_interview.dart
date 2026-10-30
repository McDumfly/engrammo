import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/claims_policy.dart'
    show aiCloudConsentBody, aiCloudConsentTitle;
import '../models/interview.dart';
import '../models/memory_verdict.dart';
import '../models/study_recommendation.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import 'learning_path.dart';
import 'memory_profile.dart';

class AssessmentInterviewPage extends StatefulWidget {
  final List<int> scores;
  final List<int> hardHits;
  final List<int> latenciesMs;
  final int xp;
  const AssessmentInterviewPage({
    super.key,
    required this.scores,
    required this.hardHits,
    required this.latenciesMs,
    this.xp = 0,
  });

  @override
  State<AssessmentInterviewPage> createState() =>
      _AssessmentInterviewPageState();
}

class _AssessmentInterviewPageState extends State<AssessmentInterviewPage> {
  int _step = 0;
  late final List<int?> _picked;
  late final List<TextEditingController> _customs;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _picked = List.filled(interviewQuestions.length, null);
    _customs = [
      for (var i = 0; i < interviewQuestions.length; i++)
        TextEditingController(),
    ];
  }

  @override
  void dispose() {
    for (final c in _customs) {
      c.dispose();
    }
    super.dispose();
  }

  List<InterviewAnswer> get _answers => [
    for (var i = 0; i < interviewQuestions.length; i++)
      InterviewAnswer(
        questionId: interviewQuestions[i].id,
        picked: _picked[i],
        custom: _customs[i].text.trim(),
      ),
  ];

  Future<bool> _askCloudConsent() async {
    final allow = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        key: const ValueKey('interview-consent-dialog'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          aiCloudConsentTitle,
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          aiCloudConsentBody,
          style: TextStyle(color: context.mutedText, height: 1.4),
        ),
        actions: [
          TextButton(
            key: const ValueKey('interview-consent-offline'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('assess_offline')),
          ),
          FilledButton(
            key: const ValueKey('interview-consent-allow'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('assess_allow')),
          ),
        ],
      ),
    );
    return allow == true;
  }

  Future<void> _analyze() async {
    if (_analyzing) return;
    if (await MetaAIService.hasAnyKey() &&
        !await MetaAIService.cloudConsent()) {
      if (!mounted) return;
      if (await _askCloudConsent()) {
        await MetaAIService.setCloudConsent(true);
      }
      if (!mounted) return;
    }
    setState(() => _analyzing = true);
    AppFeedback.medium();
    final tiedTop = widget.scores.isEmpty
        ? <int>[]
        : [
            for (var i = 0; i < widget.scores.length; i++)
              if (widget.scores[i] ==
                  widget.scores.reduce((a, b) => a > b ? a : b))
                i,
          ];
    final results = await Future.wait([
      MetaAIService.analyzeMemoryType(
        scores: widget.scores,
        answers: _answers,
        hardHits: widget.hardHits,
        tiedTop: tiedTop,
      ),
      MetaAIService.recommendStudyTrack(
        scores: widget.scores,
        answers: _answers,
        hardHits: widget.hardHits,
        latenciesMs: widget.latenciesMs,
        tiedTop: tiedTop,
      ),
    ]);
    final verdict = results[0] as MemoryVerdict;
    final studyChoice = results[1] as StudyRecommendation;
    await MemoryStore.saveDominantKind(
      verdict.kind,
      rationale: verdict.rationale,
      ai: !verdict.fallback,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MemoryResultPage(
          scores: widget.scores,
          xp: widget.xp,
          hardHits: widget.hardHits,
          latenciesMs: widget.latenciesMs,
          verdict: verdict,
          recommendation: studyChoice,
          onStartTrack: _startTrack,
        ),
      ),
    );
  }

  void _startTrack(int track) {
    AppFeedback.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningPathPage(initialTrack: track),
      ),
    );
  }

  void _skip() {
    if (_analyzing) return;
    AppFeedback.light();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MemoryResultPage(
          scores: widget.scores,
          xp: widget.xp,
          hardHits: widget.hardHits,
          latenciesMs: widget.latenciesMs,
          onStartTrack: _startTrack,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        key: const ValueKey('interview-exit-dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('assess_leave'),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          tr('assess_leave_body'),
          style: TextStyle(color: context.mutedText),
        ),
        actions: [
          TextButton(
            key: const ValueKey('interview-exit-stay'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: Text(tr('assess_keep')),
          ),
          FilledButton(
            key: const ValueKey('interview-exit-leave'),
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            child: Text(tr('assess_leave_btn')),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _onBackPressed() async {
    final leave = await _confirmExit();
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = interviewQuestions[_step];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: EngramBackButton(onPressed: _onBackPressed),
        title: Text(
          tr('assess_title', {
            'n': _step + 1,
            'total': interviewQuestions.length,
          }),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          AiHelpButton(
            topic: AiHelpTopics.assessment,
            helpContext: tr('assess_help_context'),
          ),
          TextButton(
            onPressed: _skip,
            child: Text(
              tr('onboarding_skip'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _step / interviewQuestions.length,
                minHeight: 6,
                backgroundColor: context.hairline,
                valueColor: const AlwaysStoppedAnimation(violet),
              ),
            ),
          ),
        ),
      ),
      body: _analyzing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: violet),
                  const SizedBox(height: 16),
                  Text(
                    tr('assess_analyzing'),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('assess_analyzing_sub'),
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tr(q.hintKey),
                    style: const TextStyle(
                      color: violetDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr(q.promptKey),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    height: 1.35,
                  ),
                ),
                if (q.constructKey.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${tr(q.constructKey)} · ${tr(q.sourceKey)}',
                    style: TextStyle(
                      color: context.mutedText,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        AppFeedback.light();
                        setState(() => _picked[_step] = i);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: _picked[_step] == i
                              ? violet.withValues(alpha: 0.12)
                              : context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _picked[_step] == i
                                ? violet
                                : context.hairline,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(q.options[i].labelKey),
                                style: TextStyle(
                                  color: context.inkText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_picked[_step] == i)
                              const HugeIcon(
                                icon:
                                    HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: violet,
                                size: 22,
                                strokeWidth: 2.2,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  tr('assess_own_words'),
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customs[_step],
                  maxLines: 3,
                  minLines: 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  style: TextStyle(color: context.inkText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: tr('assess_example'),
                    hintStyle: TextStyle(color: context.mutedText),
                    filled: true,
                    fillColor: context.cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.hairline,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.hairline,
                        width: 2,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: violet, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            AppFeedback.light();
                            setState(() => _step--);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: context.hairline,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            tr('assess_back'),
                            style: TextStyle(
                              color: context.inkText,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: EngramButton(
                        label: _step + 1 < interviewQuestions.length
                            ? tr('common_next')
                            : tr('assess_analyze'),
                        onPressed: () {
                          AppFeedback.medium();
                          if (_step + 1 < interviewQuestions.length) {
                            setState(() => _step++);
                          } else {
                            _analyze();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }
}
