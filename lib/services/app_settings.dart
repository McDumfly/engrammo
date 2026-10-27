import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Az app beállításai: sötét mód + haptika (rezgő visszajelzés).
///
/// Mindkét kapcsoló a készüléken marad meg ([SharedPreferences]), és
/// átállításkor azonnal érvényesül az egész appban:
/// - [darkMode]: a [MaterialApp.themeMode] sötét/világos témát vált.
/// - [haptics]: az [AppFeedback] összes rezgését némítja/feloldja.
///
/// Betöltéskor a mentett értékek jönnek vissza, hiba esetén maradnak az
/// alapértelmezettek (világos téma, rezgés bekapcsolva).
class AppSettings extends ChangeNotifier {
  static const _darkKey = 'settings_dark_mode_v1';
  // A kulcs értéke szándékosan a régi, hogy a korábbi mentés megmaradjon.
  static const _hapticsKey = 'settings_sounds_v1';

  bool _darkMode = false;
  bool _haptics = true;

  bool get darkMode => _darkMode;
  bool get haptics => _haptics;

  /// Horog a felhő-szinkronnak: a kapcsolók átállítása után lefut.
  /// Az Auth-réteg köti be, így a beállítások nem függenek a Firebase-től.
  void Function()? onChanged;

  void _notifyChanged() => onChanged?.call();

  /// Mentett értékek visszatöltése (pl. induláskor a `main`-ből).
  /// Teszt-környezetben, ahol nincs tároló plugin, csendben az
  /// alapértelmezettek maradnak.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkMode = prefs.getBool(_darkKey) ?? false;
      _haptics = prefs.getBool(_hapticsKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Nincs tároló (pl. widget-teszt): maradnak az alapértékek.
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkKey, value);
    } catch (_) {
      // Mentés sikertelen: a memóriabeli érték ettől még él.
    }
    _notifyChanged();
  }

  Future<void> setHaptics(bool value) async {
    if (_haptics == value) return;
    _haptics = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticsKey, value);
    } catch (_) {
      // Mentés sikertelen: a memóriabeli érték ettől még él.
    }
    _notifyChanged();
  }
}

/// Az egész app által figyelt, közös beállítás-példány.
final appSettings = AppSettings();
