import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

/// Az app összes rezgő visszajelzése ezen megy keresztül.
///
/// A Beállításokban lévő "Haptic" kapcsoló ezt némítja: ha
/// [AppSettings.haptics] ki van kapcsolva, ezek a hívások nem csinálnak
/// semmit. Így a kapcsoló valóban az egész app rezgésvilágát
/// fogja, nem csak egy képernyőt.
///
/// Az egymást azonnal követő hívásokból csak az első rezeg
/// ([_minGap]): egy koppintás két helyről (pl. a gomb belülről +
/// a kezelőfüggvény) se adjon dupla rezgést. A tudatosan
/// később jövő visszajelzést (sikeres mentés, találat) ez nem
/// érinti, azokhoz képest a rés mindig nagyobb.
class AppFeedback {
  const AppFeedback._();

  /// Két rezgés között ennyi időnek kell eltelnie. Egy koppintás
  /// duplán elsült hívásai mikroszekundumokra vannak egymástól,
  /// a szándékos második jelzés (pl. mentés ✓) viszont mindig
  /// később jön — a kettő közé esik ez az ablak.
  static const _minGap = Duration(milliseconds: 80);

  static DateTime? _lastFire;

  static bool _claimSlot() {
    final now = DateTime.now();
    final last = _lastFire;
    if (last != null && now.difference(last) < _minGap) return false;
    _lastFire = now;
    return true;
  }

  /// Csak teszteknek: a rés-ablak nullázása, hogy az esetek ne
  /// függjenek egymás időzítésétől.
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
