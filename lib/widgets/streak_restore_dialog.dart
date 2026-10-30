import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart' show orange, coral;
import '../models/collectibles.dart' show engram;
import '../utils/streak_restore.dart';

class StreakRestoreDialog extends StatelessWidget {
  final RestorePlan plan;
  final int engrams;
  final VoidCallback onRestore;
  final VoidCallback onLater;

  const StreakRestoreDialog({
    super.key,
    required this.plan,
    required this.engrams,
    required this.onRestore,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final cost = StreakRestore.streakRestoreCost(plan.missedDays);
    final affordable = engrams >= cost;
    return Dialog(
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.mutedText.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFire,
                color: context.mutedText,
                size: 44,
                strokeWidth: 2.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('streak_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: context.inkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plan.restoredStreak.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 48,
                height: 1.0,
                color: coral,
              ),
            ),
            Text(
              tr('streak_day_streak'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${plan.missedDays == 1 ? tr('streak_missed_one') : tr('streak_missed_many', {'n': plan.missedDays})}'
              ' ${tr('streak_body', {'cost': cost, 'days': plan.restoredStreak})}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: affordable
                    ? orange.withValues(alpha: 0.12)
                    : coral.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: engram.icon,
                    color: affordable ? orange : coral,
                    size: 18,
                    strokeWidth: 2.0,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('streak_balance', {'n': engrams}),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: affordable ? context.inkText : coral,
                    ),
                  ),
                ],
              ),
            ),
            if (!affordable) ...[
              const SizedBox(height: 8),
              Text(
                tr('streak_poor'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: coral, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            EngramButton(
              label: tr('streak_restore_for', {'cost': cost}),
              onPressed: affordable ? onRestore : null,
            ),
            const SizedBox(height: 10),
            EngramButton(
              label: tr('streak_later'),
              variant: EngramButtonVariant.secondary,
              onPressed: onLater,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmStreakRestore(
  BuildContext context,
  RestorePlan plan,
) async {
  final cost = StreakRestore.streakRestoreCost(plan.missedDays);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        tr('streak_confirm_title'),
        style: TextStyle(color: context.inkText, fontWeight: FontWeight.w800),
      ),
      content: Text(
        '${plan.missedDays == 1 ? tr('streak_missed_one') : tr('streak_missed_many', {'n': plan.missedDays})}'
        ' ${tr('streak_confirm_body', {'cost': cost, 'days': plan.restoredStreak})}',
        style: TextStyle(color: context.mutedText),
      ),
      actions: [
        TextButton(
          onPressed: () {
            AppFeedback.light();
            Navigator.pop(ctx, false);
          },
          child: Text(tr('common_cancel')),
        ),
        FilledButton(
          onPressed: () {
            AppFeedback.light();
            Navigator.pop(ctx, true);
          },
          child: Text(tr('streak_restore')),
        ),
      ],
    ),
  );
  return confirmed == true;
}
