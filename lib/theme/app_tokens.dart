import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Design tokens: radii, spacing and the AppText type scale.
/// Single source of truth for every new/changed widget.
class AppRadius {
  static const double s = 10;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Spacing grid: only 4/8/12/16/24/32 in new code.
class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Type scale, Lexend. Minimum size 12. Weights w500-w800 only
/// (w900 lives inside EngramButton alone).
class AppText {
  static const TextStyle display = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
  static const TextStyle title = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );
}
