import '../l10n/app_localizations.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => 'UsernameTakenException';
}

class ProfileSetupRules {
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int maxDisplayNameLength = 40;

  static final RegExp _allowedUsername = RegExp(r'^[a-z0-9_.]+$');

  static String normalizeUsername(String raw) =>
      raw.trim().toLowerCase().replaceAll(' ', '_');

  static String? validateUsername(String raw) {
    final name = normalizeUsername(raw);
    if (name.isEmpty) return tr('profile_pick_username');
    if (name.length < minUsernameLength) {
      return tr('profile_username_too_short', {'n': minUsernameLength});
    }
    if (name.length > maxUsernameLength) {
      return tr('profile_username_too_long', {'n': maxUsernameLength});
    }
    if (!_allowedUsername.hasMatch(name)) {
      return tr('profile_username_charset');
    }
    if (name.startsWith('.') ||
        name.startsWith('_') ||
        name.endsWith('.') ||
        name.endsWith('_')) {
      return tr('profile_username_edges');
    }
    if (name.contains('..')) return tr('profile_username_double_dot');
    return null;
  }

  static String? validateDisplayName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return tr('profile_add_name');
    if (name.length > maxDisplayNameLength) {
      return tr('profile_name_too_long', {'n': maxDisplayNameLength});
    }
    return null;
  }
}
