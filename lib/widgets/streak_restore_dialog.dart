import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import 'app_buttons.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart' show amber, coral;
import '../models/collectibles.dart' show engram;
import '../utils/streak_restore.dart';

/// Széria-visszaállítás dialógus a kreeds-app
/// `StreakRestorePrompt` mintájára, Engrammo-stílusban.
///
/// Törött láng, visszaállított szériaszám, fix 450 engram ár
/// és egyenleg-pill. Kevés engramnál a főgomb inaktív, a felirat
/// megmondja, hogy játékkal gyűjthető.
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
              'Streak restore',
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
              'DAY STREAK',
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${plan.missedDays == 1 ? '1 missed day' : '${plan.missedDays} missed days'}'
              ' filled for $cost engrams — your streak continues'
              ' at ${plan.restoredStreak} days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    affordable
                        ? amber.withValues(alpha: 0.12)
                        : coral.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: engram.icon,
                    color: affordable ? amber : coral,
                    size: 18,
                    strokeWidth: 2.0,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$engrams engrams',
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
              const Text(
                'Not enough engrams yet — play more to collect them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: coral, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            EngramButton(
              label: 'Restore for $cost engrams',
              onPressed: affordable ? onRestore : null,
            ),
            const SizedBox(height: 10),
            EngramButton(
              label: 'Later',
              variant: EngramButtonVariant.secondary,
              onPressed: onLater,
            ),
          ],
        ),
      ),
    );
  }
}

/// Visszaállítás-megerősítés a széria-képernyő mintájára:
/// költség + pótolt napok + visszaállított hossz egy kérdésben.
Future<bool> confirmStreakRestore(
  BuildContext context,
  RestorePlan plan,
) async {
  final cost = StreakRestore.streakRestoreCost(plan.missedDays);
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Restore streak?',
            style: TextStyle(color: context.inkText, fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${plan.missedDays == 1 ? '1 missed day' : '${plan.missedDays} missed days'}'
            ' for $cost engrams. Your streak will be'
            ' ${plan.restoredStreak} days.',
            style: TextStyle(color: context.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppFeedback.light();
                Navigator.pop(ctx, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                AppFeedback.light();
                Navigator.pop(ctx, true);
              },
              child: const Text('Restore'),
            ),
          ],
        ),
  );
  return confirmed == true;
}
