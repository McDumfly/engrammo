import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/room_palace.dart' show palaceHumanDate;
import '../screens/benchmark.dart' show benchGameIcon, openPracticeGame;
import '../screens/room_palace_page.dart' show RoomPalacePage;
import '../services/app_feedback.dart';
import '../services/session_coach.dart';
import '../theme/app_colors.dart' show blue, coral, orange, teal;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_buttons.dart';
import 'app_kit.dart';

/// Delay curve for staggered entrances: holds 0 for the first [start]
/// fraction, then easeOutCubic. Test-safe (no timers).
class _CoachStagger extends Curve {
  final double start;
  const _CoachStagger(this.start);

  @override
  double transform(double t) {
    if (t <= start) return 0;
    return Curves.easeOutCubic.transform((t - start) / (1 - start));
  }
}

/// One-tap entry to the Session Coach agent: Muse Spark inspects the real
/// learner state through read-only tools, a validator checks the plan, and
/// the UI shows both the plan and how it was made.
class SessionCoachCard extends StatefulWidget {
  final VoidCallback? onGoHome;
  const SessionCoachCard({super.key, this.onGoHome});

  @override
  State<SessionCoachCard> createState() => _SessionCoachCardState();
}

class _SessionCoachCardState extends State<SessionCoachCard> {
  bool _running = false;
  CoachResult? _result;
  CoachSnapshot? _snapshot;
  List<CoachStep> _trace = const [];
  int _runId = 0;
  final GlobalKey _goKey = GlobalKey();
  late final Future<CoachRun?> _replayFuture = CoachRun.load();

  static const _emptySnapshot = CoachSnapshot(
    palaces: [],
    pathLessonsDue: 0,
    leastPracticedGame: 'sequence',
    dominantTrack: 'unknown',
    streak: 0,
    goalTitles: [],
  );

  Future<void> _start() async {
    final id = ++_runId;
    setState(() {
      _running = true;
      _result = null;
      _trace = const [];
    });
    CoachSnapshot s;
    try {
      s = await CoachSnapshot.load();
    } catch (_) {
      s = _emptySnapshot;
    }
    if (!mounted || id != _runId) return;
    setState(() => _snapshot = s);
    final r = await SessionCoach.plan(
      snapshot: s,
      locale: AppLocalizations.localeCode,
      onStep: (st) {
        if (mounted && id == _runId) {
          // A real validator rejection shudders once, right when it lands.
          if (st.kind == 'reject') AppFeedback.medium();
          setState(() => _trace = [..._trace, st]);
        }
      },
    );
    if (!mounted || id != _runId) return;
    setState(() {
      _result = r;
      _trace = List<CoachStep>.of(r.trace);
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || id != _runId) return;
    setState(() {
      _running = false;
    });
    // The "Let's go" button can land under the floating bottom nav bar.
    // Nudge it into view once the result rows are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || id != _runId) return;
      final ctx = _goKey.currentContext;
      if (ctx == null) return;
      if (Scrollable.maybeOf(ctx) == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      if (bottom > MediaQuery.sizeOf(context).height - 120) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.6,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _palaceName(String id) {
    final s = _snapshot;
    if (s != null) {
      for (final p in s.palaces) {
        if (p.id == id) return p.name;
      }
    }
    return id;
  }

  Future<void> _openItem(CoachItem item) async {
    switch (item.type) {
      case CoachItemType.roomReview:
        AppFeedback.light();
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoomPalacePage(reviewId: item.ref)),
        );
        if (mounted) setState(() {});
      case CoachItemType.practiceGame:
        await openPracticeGame(context, item.ref);
        if (mounted) setState(() {});
      case CoachItemType.pathLesson:
        widget.onGoHome?.call();
    }
  }

  /// Human label for a trace step: tool names become plain sentences,
  /// the raw validator reason never appears in the timeline.
  String _stepLabel(CoachStep st) {
    switch (st.kind) {
      case 'reject':
        return tr('coach_step_rejected');
      case 'accept':
        return tr('coach_trace_accepted');
      case 'fallback':
        return tr('coach_step_fallback');
      default:
        return switch (st.label) {
          'get_due_reviews' => tr('coach_step_due'),
          'get_learner_snapshot' => tr('coach_step_snapshot'),
          'get_goals' => tr('coach_step_goals'),
          'submit_plan' => tr('coach_step_submit'),
          _ => tr('coach_step_generic'),
        };
    }
  }

  /// A submit row is struck through when the checker rejected it later.
  bool _isStruck(int i) => _struckIn(_trace, i);

  bool _struckIn(List<CoachStep> t, int i) {
    final st = t[i];
    if (st.kind != 'tool' || st.label != 'submit_plan') return false;
    return t.skip(i + 1).any((s) => s.kind == 'reject');
  }

  Widget _nodeBox(Widget node) {
    return SizedBox(width: 24, height: 24, child: Center(child: node));
  }

  Widget _popNode({required Color color, required dynamic icon}) {
    return _nodeBox(
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => Transform.scale(
          scale: t,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: HugeIcon(icon: icon, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }

  /// One timeline row: node rail on the left, human label on the right.
  /// New rows slide up 8px and fade in.
  Widget _timelineRow(int i) {
    final st = _trace[i];
    final last = i == _trace.length - 1;
    final rejected = st.kind == 'reject';
    final struck = _isStruck(i);
    Widget node;
    if (rejected) {
      // Three 4 px sideways shakes over 360 ms, then the node rests.
      node = _nodeBox(
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 360),
          builder: (context, t, child) => Transform.translate(
            offset: Offset(4 * sin(t * 6 * pi), 0),
            child: child,
          ),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: coral,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      );
    } else if (st.kind == 'accept') {
      node = _popNode(
        color: teal,
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      );
    } else if (st.kind == 'fallback') {
      node = _nodeBox(
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: blue, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: Colors.white,
            size: 14,
          ),
        ),
      );
    } else if (last && _running) {
      node = _nodeBox(
        const AppLoader(size: 18, stroke: 2.5, color: teal, instant: true),
      );
    } else {
      node = _popNode(color: teal, icon: HugeIcons.strokeRoundedTick02);
    }
    final style = rejected
        ? AppText.body.copyWith(color: context.accentText(orange))
        : struck
        ? AppText.body.copyWith(
            color: context.mutedText,
            decoration: TextDecoration.lineThrough,
          )
        : AppText.body.copyWith(
            color: last && _running ? context.inkText : context.mutedText,
            fontWeight: last && _running ? FontWeight.w600 : FontWeight.w500,
          );
    return TweenAnimationBuilder<double>(
      key: ValueKey('coach-trace-$i'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              node,
              if (!last)
                Container(width: 2, height: 20, color: context.hairline),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: style,
                child: Text(_stepLabel(st)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Blank-card state: one loader row while the trace is still empty.
  Widget _startingRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _nodeBox(
              const AppLoader(
                size: 18,
                stroke: 2.5,
                color: teal,
                instant: true,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              tr('coach_step_start'),
              style: AppText.body.copyWith(
                color: context.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One collapsed detail row: human label, plus the raw validator
  /// reason for rejections.
  Widget _detailRow(int i) => _detailRowFor(_trace, i);

  /// Same as [_detailRow] but for a recorded run: identical rows, and
  /// the sheet never touches the learner's live plan.
  Widget _detailRowFor(List<CoachStep> t, int i) {
    final st = t[i];
    final struck = _struckIn(t, i);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepLabel(st),
            style: AppText.caption.copyWith(
              color: struck ? context.mutedText : context.inkText,
              decoration: struck ? TextDecoration.lineThrough : null,
            ),
          ),
          if (st.kind == 'reject') ...[
            const SizedBox(height: 2),
            Text(
              st.label,
              style: AppText.micro.copyWith(color: context.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  /// "How this plan was made": the finished trace, folded. Shown above
  /// the plan button while idle, below "Plan again" once finished.
  Widget _traceDisclosure() {
    return AppDisclosure(
      title: Text(
        tr('coach_trace_title'),
        style: AppText.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: context.mutedText,
        ),
      ),
      children: [
        for (var i = 0; i < _trace.length; i++)
          Align(alignment: Alignment.centerLeft, child: _detailRow(i)),
      ],
    );
  }

  /// Recorded-trace sheet: the same detail rows as the live trace under
  /// an honest "Recorded {date}" header. Read-only: opening it never
  /// changes the learner's plan.
  Future<void> _openRecordedRun(CoachRun run) {
    final date = palaceHumanDate(run.recordedAt, AppLocalizations.localeCode);
    return showAppSheet<void>(
      context,
      builder: (_) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('coach_run_recorded', {'date': date}),
              style: AppText.heading.copyWith(color: context.inkText),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < run.trace.length; i++)
              Align(
                alignment: Alignment.centerLeft,
                child: _detailRowFor(run.trace, i),
              ),
          ],
        ),
      ),
    );
  }

  /// Debug-only capture tool: exports the finished LIVE run so the lead
  /// can bundle it as `assets/demo/coach_run.json`. Refuses local runs.
  Future<void> _exportRun() async {
    final r = _result;
    if (r == null || !r.live) {
      if (!mounted) return;
      showAppToast(
        context,
        'Only a live run exports — plan first with a key.',
        kind: ToastKind.warning,
      );
      return;
    }
    try {
      final run = CoachRun(
        recordedAt: DateTime.now(),
        trace: List<CoachStep>.of(r.trace),
        items: List<CoachItem>.of(r.items),
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/coach_run.json');
      await file.writeAsString(jsonEncode(run.toJson()));
      if (!mounted) return;
      showAppToast(context, file.path, kind: ToastKind.success);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, 'Export failed.', kind: ToastKind.error);
    }
  }

  /// "See a real agent run": hidden until the recorded asset exists, so
  /// the card behaves exactly as today without it.
  Widget _replayLink() {
    return FutureBuilder<CoachRun?>(
      future: _replayFuture,
      builder: (context, snap) {
        final run = snap.data;
        if (run == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Center(
            child: AppLinkButton(
              key: const ValueKey('coach-see-real-run'),
              label: tr('coach_see_real_run'),
              onTap: () => _openRecordedRun(run),
            ),
          ),
        );
      },
    );
  }

  Widget _itemRow(CoachItem item, int i) {
    final icon = switch (item.type) {
      CoachItemType.roomReview => HugeIcons.strokeRoundedCamera01,
      CoachItemType.practiceGame => benchGameIcon(item.ref),
      CoachItemType.pathLesson => HugeIcons.strokeRoundedRoute01,
    };
    final text = switch (item.type) {
      CoachItemType.roomReview => tr('coach_item_room', {
        'name': _palaceName(item.ref),
      }),
      CoachItemType.practiceGame => tr('coach_item_game', {
        'name': tr('bench_game_${item.ref}_title'),
      }),
      CoachItemType.pathLesson => tr('coach_item_path'),
    };
    final why = switch (item.why) {
      CoachWhy.spacing => tr('coach_why_spacing'),
      CoachWhy.testing => tr('coach_why_testing'),
      CoachWhy.weak => tr('coach_why_weak'),
      CoachWhy.goal => tr('coach_why_goal'),
      CoachWhy.fresh => tr('coach_why_fresh'),
    };
    final total = 220 + 60 * i;
    return TweenAnimationBuilder<double>(
      key: ValueKey('coach-plan-$i'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: _CoachStagger(60 * i / total),
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: Tappable(
        onTap: () => _openItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  color: teal,
                  size: 22,
                  strokeWidth: 2.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: AppText.body.copyWith(
                        color: context.inkText,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      why,
                      style: AppText.caption.copyWith(color: context.mutedText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('coach_minutes', {'min': item.minutes}),
                      style: AppText.micro.copyWith(color: context.mutedText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: context.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Container(
      key: const ValueKey('session-coach-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAiBrain01,
                    color: teal,
                    size: 26,
                    strokeWidth: 2.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('coach_title'),
                        style: AppText.heading.copyWith(color: context.inkText),
                      ),
                      const SizedBox(height: 2),
                      if (result == null || _running)
                        Text(
                          tr('coach_sub'),
                          style: AppText.caption.copyWith(
                            color: context.mutedText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(width: 8),
                  AppBadge(
                    label: result.live ? 'Muse Spark' : tr('coach_local'),
                    color: result.live ? teal : blue,
                  ),
                ],
              ],
            ),
          ),
          if (_running || result == null) const SizedBox(height: 12),
          if (_running || result != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              alignment: Alignment.topCenter,
              child: _running
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_trace.isEmpty)
                          _startingRow()
                        else
                          for (var i = 0; i < _trace.length; i++)
                            _timelineRow(i),
                      ],
                    )
                  : result == null
                  ? _traceDisclosure()
                  : const SizedBox.shrink(),
            ),
          if (!_running && result == null) ...[
            EngramButton(label: tr('coach_build_btn'), onPressed: _start),
          ],
          if (!_running && result != null) ...[
            for (var i = 0; i < result.items.length; i++) ...[
              if (i > 0) const AppDivider(),
              _itemRow(result.items[i], i),
            ],
            const SizedBox(height: 12),
            EngramButton(
              key: _goKey,
              label: tr('coach_start'),
              height: 52,
              onPressed: () => _openItem(result.items.first),
            ),
            Center(
              child: EngramTextButton(
                icon: HugeIcons.strokeRoundedRefresh,
                label: tr('coach_replan'),
                onPressed: _start,
              ),
            ),
            const SizedBox(height: 12),
            _traceDisclosure(),
            if (kDebugMode)
              Center(
                child: AppLinkButton(
                  label: 'Export as coach run',
                  onTap: _exportRun,
                ),
              ),
            const SizedBox(height: 16),
          ],
          _replayLink(),
        ],
      ),
    );
  }
}
