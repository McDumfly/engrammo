import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/google_g_logo.dart';
import '../theme/app_colors.dart' show coral, ink, teal, blue;
import '../services/app_feedback.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import 'memory_profile.dart' show MemoryAssessmentIntroPage;

/// Beállítások: profil, fiók, preferenciák, Meta AI-kulcs, danger zone.
/// - Account: email + jelszócsere, csak ha nem Google-belépés
///   ([isGoogleUser] == false). Google-felhasználó infósávot lát.
/// - A profil- és kapcsolóváltozások bejelentkezve a felhőbe is
///   szinkronizálódnak ([CloudSync]), kijelentkezve helyben maradnak.
/// - Danger zone: fióktörlés megerősítő dialógussal.
/// Nincs toast / snackbar / értesítés-UI.
class SettingsScreen extends StatefulWidget {
  final bool isGoogleUser;
  final String initialDisplayName;
  final String initialUsername;
  final String initialEmail;

  const SettingsScreen({
    super.key,
    this.isGoogleUser = false,
    this.initialDisplayName = '',
    this.initialUsername = '',
    this.initialEmail = '',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _apiKeyCtrl;
  String? _profileNote;
  String? _apiKeyNote;
  bool _hasStoredKey = false;
  bool _hasBundledKey = false;
  bool _apiKeyBusy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayName);
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
    _apiKeyCtrl = TextEditingController();
    _loadApiKeyStatus();
  }

  Future<void> _loadApiKeyStatus() async {
    final stored = await MetaAIService.storedApiKey();
    if (!mounted) return;
    setState(() {
      _hasStoredKey = stored.isNotEmpty;
      _hasBundledKey = MetaAIService.bundledApiKey.isNotEmpty;
    });
  }

  Future<void> _saveApiKey() async {
    final value = _apiKeyCtrl.text.trim();
    if (value.isEmpty) {
      setState(() => _apiKeyNote = 'Enter a key first.');
      return;
    }
    setState(() {
      _apiKeyBusy = true;
      _apiKeyNote = null;
    });
    try {
      await MetaAIService.setStoredApiKey(value);
      _apiKeyCtrl.clear();
      // Nincs rárezgés: a gomb koppintása már rezgett, a sikert a ✓ mutatja.
      if (!mounted) return;
      setState(() {
        _hasStoredKey = true;
        _apiKeyNote = 'Saved ✓ Stays live on plain launches too.';
      });
      // Első kulcs + még nincs szintmérő: egyből feljön a
      // szintfelmérő + domináns memóriatípus-megállapítás.
      final scores = await MemoryStore.loadScores();
      if (!mounted) return;
      if (scores == null || scores.isEmpty) {
        setState(() => _apiKeyNote = 'Saved ✓ Now discover your memory type!');
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoryAssessmentIntroPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _apiKeyNote = 'Save failed.');
    } finally {
      if (mounted) setState(() => _apiKeyBusy = false);
    }
  }

  Future<void> _clearApiKey() async {
    setState(() {
      _apiKeyBusy = true;
      _apiKeyNote = null;
    });
    await MetaAIService.clearStoredApiKey();
    if (!mounted) return;
    // Nincs rárezgés: a gomb koppintása már rezgett.
    setState(() {
      _hasStoredKey = false;
      _apiKeyBusy = false;
      _apiKeyNote = 'Deleted, offline fallback runs again.';
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _acknowledge() {
    AppFeedback.light();
  }

  /// Profil mentése helybe + (belépve) a Firebase-profilba és a felhőbe.
  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().replaceAll(' ', '_');
    await MemoryStore.saveProfile(
      displayName: name,
      username: username,
      email: authService.email,
    );
    try {
      if (authService.signedIn && name.isNotEmpty) {
        await authService.updateDisplayName(name);
      }
      // Nincs rárezgés: a gomb koppintása már rezgett, a sikert a ✓ mutatja.
      if (!mounted) return;
      setState(() => _profileNote = 'Saved ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => _profileNote = AuthService.messageFor(e));
    }
  }

  void _openEmailEditor() {
    // Névtelen / helyi vendég: nincs mihez emailt cserélni,
    // előbb megmaradó fiók kell (profilkártya → belépés).
    if (!authService.isPermanentAccount) {
      setState(
        () => _profileNote = authService.signedIn
            ? 'Guest account — sign in on the Profile tab to set an email.'
            : 'Sign in first to change your email.',
      );
      return;
    }
    final ctrl = TextEditingController(text: authService.email);
    var note = '';
    var busy = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final sheetNav = Navigator.of(sheetCtx);
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Grabber(),
                const SizedBox(height: 12),
                Text(
                  'Change email',
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We send a verification link — the address changes after you tap it.',
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(controller: ctrl, hint: 'you@example.com'),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFFE5484D),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                EngramButton(
                  label: busy ? 'SENDING…' : 'SEND VERIFICATION',
                  isLoading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          final next = ctrl.text.trim();
                          if (!next.contains('@')) {
                            setSheet(
                              () => note = 'Adj meg egy érvényes email-címet.',
                            );
                            return;
                          }
                          setSheet(() {
                            busy = true;
                            note = '';
                          });
                          try {
                            await authService.updateEmailAddress(next);
                            sheetNav.pop();
                            _acknowledge();
                            if (!mounted) return;
                            setState(
                              () => _profileNote = 'Verification sent to $next',
                            );
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              note = AuthService.messageFor(e);
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPasswordEditor() {
    if (!authService.isPermanentAccount) {
      setState(
        () => _profileNote = authService.signedIn
            ? 'Guest account — sign in on the Profile tab to set a password.'
            : 'Sign in first to change your password.',
      );
      return;
    }
    final fresh = TextEditingController();
    var note = '';
    var busy = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final sheetNav = Navigator.of(sheetCtx);
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Grabber(),
                const SizedBox(height: 12),
                Text(
                  'Change password',
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'New password takes effect immediately. You may need to sign in again first.',
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(controller: fresh, hint: 'New password', obscure: true),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFFE5484D),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                EngramButton(
                  label: busy ? 'SAVING…' : 'SAVE PASSWORD',
                  isLoading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          if (fresh.text.length < 6) {
                            setSheet(
                              () =>
                                  note = 'A jelszó legalább 6 karakter legyen.',
                            );
                            return;
                          }
                          setSheet(() {
                            busy = true;
                            note = '';
                          });
                          try {
                            await authService.updatePassword(fresh.text);
                            sheetNav.pop();
                            _acknowledge();
                            if (!mounted) return;
                            setState(() => _profileNote = 'Password updated ✓');
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              note = AuthService.messageFor(e);
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    AppFeedback.medium();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.hairline, width: 2),
        ),
        title: Text(
          'Delete account?',
          style: TextStyle(
            color: Theme.of(dlgCtx).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'This permanently deletes your profile, progress and engrams.',
          style: TextStyle(
            color: Theme.of(dlgCtx).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(false);
            },
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: coral),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await authService.deleteAccount();
      if (!mounted) return;
      AppFeedback.heavy();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _profileNote = AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A témakapcsoló azonnal újrarajzolja ezt a képernyőt is.
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                // A rezgést az EngramBackButton adja.
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                        icon: HugeIcons.strokeRoundedUserCircle,
                        title: 'Profile',
                        subtitle: 'How you appear to others',
                      ),
                      _Card(
                        child: Column(
                          children: [
                            _FieldLabel(label: 'Display name'),
                            const SizedBox(height: 6),
                            _Field(controller: _nameCtrl, hint: 'Your name'),
                            const SizedBox(height: 12),
                            _FieldLabel(label: 'Username'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _usernameCtrl,
                              hint: 'username',
                              prefix: '@',
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: 'SAVE PROFILE',
                              onPressed: _saveProfile,
                            ),
                            if (_profileNote != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _profileNote!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        icon: HugeIcons.strokeRoundedMail01,
                        title: 'Account',
                        subtitle: 'Email and sign-in',
                      ),
                      if (widget.isGoogleUser)
                        const _Card(child: _GoogleBanner())
                      else
                        _Card(
                          child: Column(
                            children: [
                              _AccountRow(
                                icon: HugeIcons.strokeRoundedMail01,
                                title: 'Email',
                                subtitle: authService.isAnonymous
                                    ? 'Guest account'
                                    : (widget.initialEmail.isEmpty
                                          ? 'Not signed in'
                                          : widget.initialEmail),
                                onTap: _openEmailEditor,
                              ),
                              Divider(
                                color: context.hairline,
                                height: 20,
                                thickness: 1.5,
                              ),
                              _AccountRow(
                                icon: HugeIcons.strokeRoundedKey01,
                                title: 'Password',
                                subtitle: '••••••••',
                                onTap: _openPasswordEditor,
                              ),
                            ],
                          ),
                        ),
                      if (authService.signedIn || authService.guestMode) ...[
                        const SizedBox(height: 10),
                        _Card(
                          child: _AccountRow(
                            icon: HugeIcons.strokeRoundedLogout01,
                            title: 'Sign out',
                            subtitle: 'Back to the sign-in screen',
                            // A rezgést a sor (_AccountRow) adja.
                            onTap: () async {
                              await authService.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        icon: HugeIcons.strokeRoundedSettings01,
                        title: 'Preferences',
                        subtitle: 'Applies instantly, saved on this device',
                      ),
                      _Card(
                        child: Column(
                          children: [
                            _SwitchRow(
                              icon: HugeIcons.strokeRoundedMoon01,
                              label: 'Dark mode',
                              value: appSettings.darkMode,
                              onChanged: (v) => appSettings.setDarkMode(v),
                            ),
                            Divider(
                              color: context.hairline,
                              height: 20,
                              thickness: 1.5,
                            ),
                            _SwitchRow(
                              icon: HugeIcons.strokeRoundedVibrate,
                              label: 'Haptic',
                              value: appSettings.haptics,
                              onChanged: (v) => appSettings.setHaptics(v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        icon: HugeIcons.strokeRoundedKey01,
                        title: 'Meta AI',
                        subtitle: 'Enter once, stays live on plain launches',
                      ),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MetaAIService.configured
                                  ? 'Provided at launch ✓'
                                  : _hasBundledKey
                                  ? 'Loaded from file ✓ (plain launch)'
                                  : _hasStoredKey
                                  ? 'Saved key active ✓'
                                  : 'No key, offline fallback runs.',
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _FieldLabel(label: 'Model API key'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _apiKeyCtrl,
                              hint: 'LLM_...',
                              obscure: true,
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: _apiKeyBusy ? 'SAVING…' : 'SAVE KEY',
                              isLoading: _apiKeyBusy,
                              onPressed: _apiKeyBusy ? null : _saveApiKey,
                            ),
                            if (_hasStoredKey) ...[
                              const SizedBox(height: 8),
                              EngramButton(
                                label: 'DELETE KEY',
                                variant: EngramButtonVariant.danger,
                                onPressed: _apiKeyBusy ? null : _clearApiKey,
                              ),
                            ],
                            if (_apiKeyNote != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _apiKeyNote!,
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        icon: HugeIcons.strokeRoundedAlert02,
                        title: 'Danger zone',
                        subtitle: 'Irreversible actions',
                        accent: coral,
                      ),
                      _Card(
                        borderColor: coral,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete account',
                              style: TextStyle(
                                color: context.inkText,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Removes your profile, progress and engrams. '
                              'This also deletes your cloud save.',
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: 'DELETE ACCOUNT',
                              variant: EngramButtonVariant.danger,
                              icon: HugeIcons.strokeRoundedDelete02,
                              // A kezelő adja a medium jelzést, a gomb nem rezeg rá.
                              haptic: false,
                              onPressed: _confirmDelete,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          EngramBackButton(boxed: true, onPressed: onBack),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Profile, account and app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = ink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
            strokeWidth: 2.2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent == coral
                        ? coral
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? context.hairline, width: 2),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: context.mutedText,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool obscure;
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: context.inkText,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: context.mutedText,
          fontWeight: FontWeight.w600,
        ),
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: context.mutedText,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: context.softBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.hairline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppFeedback.light();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.softBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.hairline, width: 2),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: icon,
              color: context.inkText,
              size: 20,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: context.mutedText,
            size: 20,
            strokeWidth: 2.2,
          ),
        ],
      ),
    );
  }
}

class _GoogleBanner extends StatelessWidget {
  const _GoogleBanner();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.softBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.hairline, width: 2),
          ),
          alignment: Alignment.center,
          child: const GoogleGLogo(size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in with Google',
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Email and password are managed by Google, '
                'so they cannot be changed here.',
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          color: context.mutedText,
          size: 22,
          strokeWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: teal,
          onChanged: (nv) {
            onChanged(nv);
          },
        ),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: context.hairline,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
