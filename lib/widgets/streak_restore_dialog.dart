import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_kit.dart';
import '../theme/app_colors.dart' show orange, coral;
import '../models/collectibles.dart' show engram;
import '../utils/streak_restore.dart';

/// Streak-restore prompt as a kit dialog; true means "restore".
Future<bool?> showStreakRestoreDialog(
  BuildContext context,
  RestorePlan plan,
  int engrams,
) {
  final cost = StreakRestore.streakRestoreCost(plan.missedDays);
  final affordable = engrams >= cost;
  return showAppDialog<bool>(
    context,
    title: tr('streak_title'),
    icon: HugeIcons.strokeRoundedFire,
    iconColor: orange,
    content: _StreakRestoreContent(
      plan: plan,
      cost: cost,
      affordable: affordable,
      engrams: engrams,
    ),
    primary: AppDialogAction(
      tr('streak_restore_for', {'cost': cost}),
      value: true,
    ),
    secondary: AppDialogAction(tr('streak_later'), value: false),
  );
}

class _StreakRestoreContent extends StatelessWidget {
  final RestorePlan plan;
  final int cost;
  final bool affordable;
  final int engrams;

  const _StreakRestoreContent({
    required this.plan,
    required this.cost,
    required this.affordable,
    required this.engrams,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plan.restoredStreak.toString(),
          style: AppText.display.copyWith(
            color: context.accentText(coral),
            fontSize: 48,
            height: 1.0,
          ),
        ),
        Text(
          tr('streak_day_streak'),
          style: AppText.micro.copyWith(
            color: context.mutedText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${plan.missedDays == 1 ? tr('streak_missed_one') : tr('streak_missed_many', {'n': plan.missedDays})}'
          ' ${tr('streak_body', {'cost': cost, 'days': plan.restoredStreak})}',
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: context.mutedText),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: affordable
                ? orange.withValues(alpha: 0.12)
                : coral.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.hairline, width: 2),
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
                style: AppText.caption.copyWith(
                  color: affordable ? context.inkText : context.dangerText,
                  fontWeight: FontWeight.w700,
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
            style: AppText.caption.copyWith(color: context.dangerText),
          ),
        ],
      ],
    );
  }
}

Future<bool> confirmStreakRestore(
  BuildContext context,
  RestorePlan plan,
) async {
  final cost = StreakRestore.streakRestoreCost(plan.missedDays);
  final confirmed = await showAppDialog<bool>(
    context,
    title: tr('streak_confirm_title'),
    body:
        '${plan.missedDays == 1 ? tr('streak_missed_one') : tr('streak_missed_many', {'n': plan.missedDays})}'
        ' ${tr('streak_confirm_body', {'cost': cost, 'days': plan.restoredStreak})}',
    icon: HugeIcons.strokeRoundedFire,
    iconColor: orange,
    primary: AppDialogAction(tr('streak_restore'), value: true),
    secondary: AppDialogAction(tr('common_cancel'), value: false),
  );
  return confirmed == true;
}
