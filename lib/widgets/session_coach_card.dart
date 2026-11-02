import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../screens/benchmark.dart' show openPracticeGame;
import '../screens/room_palace_page.dart' show RoomPalacePage;
import '../services/app_feedback.dart';
import '../services/session_coach.dart';
import '../theme/app_colors.dart' show orange, teal;
import '../theme/app_theme.dart';
import 'app_buttons.dart';

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
          setState(() => _trace = [..._trace, st]);
        }
      },
    );
    if (!mounted || id != _runId) return;
    setState(() {
      _result = r;
      _running = false;
      _trace = List<CoachStep>.of(r.trace);
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

  Widget _traceLine(CoachStep st) {
    switch (st.kind) {
      case 'tool':
        return Text(
          tr('coach_trace_tool', {'tool': st.label}),
          style: TextStyle(color: context.mutedText, fontSize: 13),
        );
      case 'reject':
        return Text(
          tr('coach_trace_rejected', {'reason': st.label}),
          style: const TextStyle(color: orange, fontSize: 13),
        );
      case 'accept':
        return Text(
          tr('coach_trace_accepted'),
          style: const TextStyle(
            color: teal,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        );
      default:
        return Text(
          tr('coach_local'),
          style: TextStyle(color: context.mutedText, fontSize: 13),
        );
    }
  }

  Widget _itemRow(CoachItem item) {
    final icon = switch (item.type) {
      CoachItemType.roomReview => HugeIcons.strokeRoundedCamera01,
      CoachItemType.practiceGame => HugeIcons.strokeRoundedGameController01,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, color: teal, size: 26, strokeWidth: 2.0),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  why,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
                Text(
                  tr('coach_minutes', {'min': item.minutes}),
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openItem(item),
            child: Text(tr('coach_start')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Container(
      key: const ValueKey('session-coach-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teal.withValues(alpha: 0.40), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (result == null && !_running)
                      Text(
                        tr('coach_sub'),
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_running) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            for (final st in _trace) _traceLine(st),
          ] else if (result == null) ...[
            const SizedBox(height: 12),
            EngramButton(label: tr('coach_build_btn'), onPressed: _start),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (result.live ? teal : orange).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                result.live ? tr('coach_live') : tr('coach_local'),
                style: TextStyle(
                  color: result.live ? teal : orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final item in result.items) _itemRow(item),
            // Transparent Material: ExpansionTile builds a ListTile, which
            // asserts when a colored DecoratedBox sits between it and the
            // nearest Material ancestor (the tinted card above).
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  tr('coach_trace_title'),
                  style: TextStyle(color: context.mutedText, fontSize: 14),
                ),
                children: [
                  for (final st in _trace)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _traceLine(st),
                      ),
                    ),
                ],
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _start,
                child: Text(tr('coach_replan')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
