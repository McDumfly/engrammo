import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class AppSettings extends ChangeNotifier {
  static const _darkKey = 'settings_dark_mode_v1';
  static const _hapticsKey = 'settings_sounds_v1';
  static const _languageKey = 'settings_language_v1';

  bool _darkMode = false;
  bool _haptics = true;
  String _languageCode = AppLocalizations.englishCode;

  bool get darkMode => _darkMode;
  bool get haptics => _haptics;
  String get languageCode => _languageCode;
  bool get isHungarian =>
      _languageCode == AppLocalizations.hungarianCode;

  void Function()? onChanged;

  void _notifyChanged() => onChanged?.call();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkMode = prefs.getBool(_darkKey) ?? false;
      _haptics = prefs.getBool(_hapticsKey) ?? true;
      final stored = prefs.getString(_languageKey);
      _languageCode = stored == AppLocalizations.hungarianCode
          ? AppLocalizations.hungarianCode
          : AppLocalizations.englishCode;
      AppLocalizations.useCode(_languageCode);
      notifyListeners();
    } catch (_) {
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
    }
    _notifyChanged();
  }

  Future<void> setLanguage(String code) async {
    final next = code == AppLocalizations.hungarianCode
        ? AppLocalizations.hungarianCode
        : AppLocalizations.englishCode;
    if (_languageCode == next) return;
    _languageCode = next;
    AppLocalizations.useCode(next);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, next);
    } catch (_) {
    }
    _notifyChanged();
  }
}

final appSettings = AppSettings();
