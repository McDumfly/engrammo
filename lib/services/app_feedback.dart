import 'package:flutter/services.dart';

import 'app_settings.dart';

/// Az app összes rezgő visszajelzése ezen megy keresztül.
///
/// A Beállításokban lévő "Haptic" kapcsoló ezt némítja: ha
/// [AppSettings.haptics] ki van kapcsolva, ezek a hívások nem csinálnak
/// semmit. Így a kapcsoló valóban az egész app rezgésvilágát
/// fogja, nem csak egy képernyőt.
class AppFeedback {
  const AppFeedback._();

  static bool get enabled => appSettings.haptics;

  static Future<void> light() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> medium() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavy() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> select() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
