import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'app_buttons.dart';
import '../theme/app_colors.dart' show coral;
import '../theme/app_theme.dart';
import '../models/collectibles.dart' show engram;

/// A kezdőképernyő felső sávja: bal oldalt az aktuális tanulási sáv
/// ikonja, jobb oldalt a széria- és engram-számláló.
/// A profil fül kivételével minden fő fülön ugyanaz látszik.
class StatsTopBar extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color tint;
  final int streak;
  final int engrams;
  final bool streakBroken;
  final VoidCallback? onIconTap;
  final VoidCallback? onStreakTap;

  const StatsTopBar({
    super.key,
    required this.icon,
    required this.tint,
    required this.streak,
    required this.engrams,
    this.streakBroken = false,
    this.onIconTap,
    this.onStreakTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EngramIconButton(
          icon: icon,
          foreground: tint,
          size: 48,
          onTap: onIconTap,
        ),
        const Spacer(),
        GestureDetector(
          onTap: onStreakTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.washBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.washBorder),
            ),
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
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.washBorder),
          ),
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
