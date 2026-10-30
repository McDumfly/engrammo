import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

class AppFeedback {
  const AppFeedback._();

  static const _minGap = Duration(milliseconds: 80);

  static DateTime? _lastFire;

  static bool _claimSlot() {
    final now = DateTime.now();
    final last = _lastFire;
    if (last != null && now.difference(last) < _minGap) return false;
    _lastFire = now;
    return true;
  }

  @visibleForTesting
  static void resetForTest() => _lastFire = null;

  static bool get enabled => appSettings.haptics;

  static Future<void> light() async {
    if (!enabled || !_claimSlot()) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> medium() async {
    if (!enabled || !_claimSlot()) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavy() async {
    if (!enabled || !_claimSlot()) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> select() async {
    if (!enabled || !_claimSlot()) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
