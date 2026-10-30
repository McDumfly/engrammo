import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/claims_policy.dart'
    show aiCloudConsentBody, aiCloudConsentTitle;
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/google_g_logo.dart';
import '../theme/app_colors.dart' show coral, ink, teal, blue;
import '../services/app_feedback.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../services/profile_setup.dart';
import '../widgets/meta_call_log.dart';
import 'memory_profile.dart' show MemoryAssessmentIntroPage;

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
  bool _profileSaving = false;
  bool _profileSaved = false;
  bool _profileError = false;
  String? _apiKeyNote;
  bool _hasStoredKey = false;
  bool _hasBundledKey = false;
  bool _apiKeyBusy = false;
  bool _aiConsent = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayName);
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
    _apiKeyCtrl = TextEditingController();
    _nameCtrl.addListener(_onProfileEdited);
    _usernameCtrl.addListener(_onProfileEdited);
    _loadApiKeyStatus();
  }

  void _onProfileEdited() {
    if (!_profileSaved && !_profileError) return;
    setState(() {
      _profileSaved = false;
      _profileError = false;
    });
  }

  Color? get _profileBorder {
    if (_profileSaved) return const Color(0xFF16A34A);
    if (_profileError) return coral;
    return null;
  }

  Future<void> _loadApiKeyStatus() async {
    final stored = await MetaAIService.storedApiKey();
    final consent = await MetaAIService.cloudConsent();
    if (!mounted) return;
    setState(() {
      _hasStoredKey = stored.isNotEmpty;
      _hasBundledKey = MetaAIService.bundledApiKey.isNotEmpty;
      _aiConsent = consent;
    });
  }

  Future<void> _saveApiKey() async {
    final value = _apiKeyCtrl.text.trim();
    if (value.isEmpty) {
      setState(() => _apiKeyNote = tr('settings_key_first'));
      return;
    }
    setState(() {
      _apiKeyBusy = true;
      _apiKeyNote = null;
    });
    try {
      await MetaAIService.setStoredApiKey(value);
      _apiKeyCtrl.clear();
      final consent = await MetaAIService.cloudConsent();
      if (!mounted) return;
      setState(() {
        _hasStoredKey = true;
        _aiConsent = consent;
        _apiKeyNote = consent
            ? tr('settings_key_saved_live')
            : tr('settings_key_saved_consent');
      });
      final scores = await MemoryStore.loadScores();
      if (!mounted) return;
      if (scores == null || scores.isEmpty) {
        setState(() => _apiKeyNote = tr('settings_key_saved_type'));
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoryAssessmentIntroPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _apiKeyNote = tr('common_save_failed'));
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
    setState(() {
      _hasStoredKey = false;
      _apiKeyBusy = false;
      _apiKeyNote = tr('settings_key_deleted');
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

  Future<void> _saveProfile() async {
    if (_profileSaving) return;
    final name = _nameCtrl.text.trim();
    final username = ProfileSetupRules.normalizeUsername(_usernameCtrl.text);
    if (username.isNotEmpty) {
      final userError = ProfileSetupRules.validateUsername(username);
      if (userError != null) {
        if (!mounted) return;
        setState(() {
          _profileNote = userError;
          _profileSaved = false;
          _profileError = true;
        });
        return;
      }
    }
    final uid = authService.user?.uid;
    setState(() {
      _profileSaving = true;
      _profileNote = null;
      _profileSaved = false;
      _profileError = false;
    });
    var previousUsername = '';
    try {
      if (uid != null &&
          username.isNotEmpty &&
          authService.backendAvailable) {
        final previous = await MemoryStore.loadProfile();
        previousUsername = previous.username;
        if (previous.username != username) {
          await CloudSync.claimUsername(
            uid: uid,
            username: username,
          ).timeout(const Duration(seconds: 10));
        }
      }
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileNote = tr('profile_username_taken');
        _profileError = true;
      });
      return;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileNote = tr('auth_no_connection');
        _profileError = true;
      });
      return;
    } on NoConnectionException {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileNote = tr('auth_no_connection');
        _profileError = true;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileSaving = false;
        _profileNote = e is StateError
            ? e.message
            : AuthService.messageFor(e);
        _profileError = true;
      });
      return;
    }
    await MemoryStore.saveProfile(
      displayName: name,
      username: username,
      email: authService.email,
    );
    if (!mounted) return;
    setState(() {
      _profileSaving = false;
      _profileSaved = true;
      _profileError = false;
      _profileNote = tr('settings_saved');
    });
    // The local save is done, the feedback is instant. Releasing the old
    // username and syncing the Auth name continue in the background and
    // do not block the green frame.
    if (previousUsername.isNotEmpty &&
        previousUsername != username &&
        uid != null) {
      unawaited(
        CloudSync.releaseUsername(uid: uid, username: previousUsername),
      );
    }
    if (authService.signedIn && name.isNotEmpty) {
      unawaited(_syncDisplayNameInBackground(name));
    }
  }

  Future<void> _syncDisplayNameInBackground(String name) async {
    try {
      await authService.updateDisplayName(name);
    } catch (_) {
      // The local save is already green: the next save retries.
    }
  }

  void _openEmailEditor() {
    if (!authService.isPermanentAccount) {
      setState(
        () => _profileNote = authService.signedIn
            ? tr('settings_guest_email')
            : tr('settings_signin_email'),
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
                  tr('settings_change_email'),
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('settings_change_email_body'),
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(controller: ctrl, hint: tr('auth_email_hint')),
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
                  label: busy
                      ? tr('settings_sending')
                      : tr('settings_send_verification'),
                  isLoading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          final next = ctrl.text.trim();
                          if (!next.contains('@')) {
                            setSheet(
                              () => note = tr('auth_invalid_email'),
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
                              () => _profileNote = tr(
                                'settings_verification_sent',
                                {'email': next},
                              ),
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
            ? tr('settings_guest_password')
            : tr('settings_signin_password'),
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
                  tr('settings_change_password'),
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('settings_change_password_body'),
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: fresh,
                  hint: tr('settings_new_password'),
                  obscure: true,
                ),
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
                  label: busy
                      ? tr('profile_saving')
                      : tr('settings_save_password'),
                  isLoading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          if (fresh.text.length < 6) {
                            setSheet(
                              () => note = tr('auth_short_password'),
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
                            setState(
                              () => _profileNote = tr(
                                'settings_password_updated',
                              ),
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
          tr('settings_delete_title'),
          style: TextStyle(
            color: Theme.of(dlgCtx).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          tr('settings_delete_body'),
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
            child: Text(tr('settings_keep')),
          ),
          TextButton(
            onPressed: () {
              AppFeedback.light();
              Navigator.of(dlgCtx).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: context.dangerText,
            ),
            child: Text(
              tr('common_delete'),
              style: const TextStyle(fontWeight: FontWeight.w900),
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
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: HugeIcons.strokeRoundedUserCircle,
                        title: tr('settings_profile'),
                        subtitle: tr('settings_profile_sub'),
                      ),
                      _Card(
                        child: Column(
                          children: [
                            _FieldLabel(
                              label: tr('settings_display_name'),
                            ),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _nameCtrl,
                              hint: tr('settings_your_name'),
                              enabled: !_profileSaving,
                              borderColor: _profileBorder,
                            ),
                            const SizedBox(height: 12),
                            _FieldLabel(
                              label: tr('settings_username'),
                            ),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _usernameCtrl,
                              hint: tr('profile_username_hint'),
                              prefix: '@',
                              enabled: !_profileSaving,
                              borderColor: _profileBorder,
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: _profileSaving
                                  ? tr('profile_saving')
                                  : tr('settings_save_profile'),
                              isLoading: _profileSaving,
                              onPressed: _profileSaving
                                  ? null
                                  : _saveProfile,
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
                      _SectionTitle(
                        icon: HugeIcons.strokeRoundedMail01,
                        title: tr('settings_account'),
                        subtitle: tr('settings_account_sub'),
                      ),
                      if (widget.isGoogleUser)
                        const _Card(child: _GoogleBanner())
                      else
                        _Card(
                          child: Column(
                            children: [
                              _AccountRow(
                                icon: HugeIcons.strokeRoundedMail01,
                                title: tr('settings_email'),
                                subtitle: authService.isAnonymous
                                    ? tr('settings_guest')
                                    : (widget.initialEmail.isEmpty
                                          ? tr('settings_not_signed')
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
                                title: tr('settings_password'),
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
                            title: tr('settings_sign_out'),
                            subtitle: tr('settings_sign_out_sub'),
                            onTap: () async {
                              await authService.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SectionTitle(
                        icon: HugeIcons.strokeRoundedSettings01,
                        title: tr('settings_prefs'),
                        subtitle: tr('settings_prefs_sub'),
                      ),
                      _Card(
                        child: Column(
                          children: [
                            _SwitchRow(
                              icon: HugeIcons.strokeRoundedMoon01,
                              label: tr('settings_dark'),
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
                              label: tr('settings_haptic'),
                              value: appSettings.haptics,
                              onChanged: (v) => appSettings.setHaptics(v),
                            ),
                            Divider(
                              color: context.hairline,
                              height: 20,
                              thickness: 1.5,
                            ),
                            _LanguageRow(
                              current: appSettings.languageCode,
                              onChanged: (code) =>
                                  appSettings.setLanguage(code),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        icon: HugeIcons.strokeRoundedKey01,
                        title: tr('settings_meta'),
                        subtitle: tr('settings_meta_sub'),
                      ),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MetaAIService.configured
                                  ? tr('settings_launch_key')
                                  : _hasBundledKey
                                  ? tr('settings_file_key')
                                  : _hasStoredKey
                                  ? tr('settings_stored_key')
                                  : tr('settings_no_key'),
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: HugeIcons.strokeRoundedShield01,
                              label: aiCloudConsentTitle,
                              value: _aiConsent,
                              onChanged: (v) async {
                                await MetaAIService.setCloudConsent(v);
                                if (!mounted) return;
                                setState(() => _aiConsent = v);
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              aiCloudConsentBody,
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FieldLabel(label: tr('settings_api_key')),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _apiKeyCtrl,
                              hint: 'LLM_...',
                              obscure: true,
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: _apiKeyBusy
                                  ? tr('profile_saving')
                                  : tr('settings_save_key'),
                              isLoading: _apiKeyBusy,
                              onPressed: _apiKeyBusy ? null : _saveApiKey,
                            ),
                            if (_hasStoredKey) ...[
                              const SizedBox(height: 8),
                              EngramButton(
                                label: tr('settings_delete_key'),
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
                            const SizedBox(height: 12),
                            Text(
                              tr('settings_recent_calls'),
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const MetaCallLogView(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        icon: HugeIcons.strokeRoundedAlert02,
                        title: tr('settings_danger'),
                        subtitle: tr('settings_danger_sub'),
                        accent: coral,
                      ),
                      _Card(
                        borderColor: coral,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('settings_delete_account'),
                              style: TextStyle(
                                color: context.inkText,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('settings_delete_account_body'),
                              style: TextStyle(
                                color: context.mutedText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            EngramButton(
                              label: tr('settings_delete_account_btn'),
                              variant: EngramButtonVariant.danger,
                              icon: HugeIcons.strokeRoundedDelete02,
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
                  tr('settings_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('settings_subtitle'),
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
          const AiHelpButton(topic: AiHelpTopics.settings),
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
                        ? context.dangerText
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
  final bool enabled;
  final Color? borderColor;
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.obscure = false,
    this.enabled = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
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
          borderSide: BorderSide(
            color: borderColor ?? context.hairline,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor ?? blue, width: 2),
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
                tr('settings_google_title'),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                tr('settings_google_body'),
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

class _LanguageRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _LanguageRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedTranslate,
          color: context.mutedText,
          size: 22,
          strokeWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tr('settings_language'),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(
              value: 'en',
              label: Text(tr('settings_english')),
            ),
            ButtonSegment<String>(
              value: 'hu',
              label: Text(tr('settings_hungarian')),
            ),
          ],
          selected: {current},
          onSelectionChanged: (selection) {
            AppFeedback.light();
            onChanged(selection.first);
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
