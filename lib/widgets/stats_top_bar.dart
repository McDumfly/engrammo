import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'app_buttons.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart' show blue, coral;
import '../theme/app_theme.dart';
import '../models/collectibles.dart' show engram;

class StatsTopBar extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color tint;
  final int streak;
  final int engrams;
  final bool streakBroken;
  final VoidCallback? onIconTap;
  final VoidCallback? onStreakTap;
  final VoidCallback? onGoalsTap;
  final int goalsCount;

  final String? iconSemanticLabel;

  const StatsTopBar({
    super.key,
    required this.icon,
    required this.tint,
    required this.streak,
    required this.engrams,
    this.streakBroken = false,
    this.onIconTap,
    this.onStreakTap,
    this.onGoalsTap,
    this.goalsCount = 0,
    this.iconSemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EngramIconButton(
          key: const ValueKey('stats-track-icon'),
          icon: icon,
          foreground: tint,
          size: 48,
          onTap: onIconTap,
          semanticLabel: iconSemanticLabel ?? tr('stats_track'),
        ),
        if (onGoalsTap != null) ...[
          const SizedBox(width: 8),
          Stack(
            key: const ValueKey('path-my-goals'),
            clipBehavior: Clip.none,
            children: [
              EngramIconButton(
                icon: HugeIcons.strokeRoundedTarget01,
                foreground: blue,
                size: 48,
                onTap: onGoalsTap,
                semanticLabel: goalsCount > 0
                    ? tr('stats_goals_count', {'n': goalsCount})
                    : tr('stats_goals'),
              ),
              if (goalsCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: context.cardBg,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      goalsCount > 99 ? '99+' : '$goalsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const Spacer(),
        Semantics(
          button: true,
          enabled: onStreakTap != null,
          label: tr('stats_streak', {'n': streak}),
          child: GestureDetector(
            onTap: onStreakTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.washBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.washBorder),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFire,
                    color: streakBroken ? context.mutedText : coral,
                    size: 18,
                    strokeWidth: 2.0,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streak',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.washBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: engram.icon,
                color: engram.color,
                size: 18,
                strokeWidth: 2.0,
              ),
              const SizedBox(width: 6),
              Text(
                '$engrams',
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
