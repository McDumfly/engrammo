import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/interview.dart';
import '../models/memory_verdict.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'memory_profile.dart';

/// Post-test interview: the self-report leg of the assessment.
///
/// Six questions about HOW the user remembers, each with four
/// selectable answers plus a free custom field. At the end the AI
/// (Muse Spark) reads the test scores together with these answers
/// and writes the dominant-type verdict; offline, the same-shaped
/// local heuristic decides so the flow never blocks.
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
  final List<int?> _picked = List.filled(6, null);
  final List<TextEditingController> _customs = [
    for (var i = 0; i < 6; i++) TextEditingController(),
  ];
  bool _analyzing = false;

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

  Future<void> _analyze() async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    AppFeedback.medium();
    // Tie-only rule: the AI may only pick among the top-tied scores,
    // never override a measured gap (enforced server-side in the prompt
    // and again when the verdict arrives).
    final tiedTop = widget.scores.isEmpty
        ? <int>[]
        : [
            for (var i = 0; i < widget.scores.length; i++)
              if (widget.scores[i] ==
                  widget.scores.reduce((a, b) => a > b ? a : b))
                i,
          ];
    final verdict = await MetaAIService.analyzeMemoryType(
      scores: widget.scores,
      answers: _answers,
      hardHits: widget.hardHits,
      tiedTop: tiedTop,
    );
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
        ),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = interviewQuestions[_step];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          'Quick interview ${_step + 1}/${interviewQuestions.length}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip',
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
                    'Analyzing your answers…',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Test scores + interview, read together.',
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
                    q.hint,
                    style: const TextStyle(
                      color: violetDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  q.prompt,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    height: 1.35,
                  ),
                ),
                if (q.construct.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${q.construct} · ${q.source}',
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
                                q.options[i].label,
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
                  'Or describe it in your own words (optional):',
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
                  style: TextStyle(color: context.inkText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'For example: I see it like a photo…',
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
                            'BACK',
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
                            ? 'NEXT'
                            : 'ANALYZE ME',
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
    );
  }
}
