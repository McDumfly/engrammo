import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/memory_store.dart';
import '../services/profile_setup.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ProfileSetupScreen({super.key, required this.onDone});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _checking = false;
  bool? _available;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _prefill();
    _usernameCtrl.addListener(_onUsernameTyped);
  }

  Future<void> _prefill() async {
    final profile = await MemoryStore.loadProfile();
    if (!mounted) return;
    final fallback = authService.user?.displayName ?? '';
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : fallback;
    if (name.isNotEmpty) _nameCtrl.text = name;
    if (profile.username.isNotEmpty) {
      _usernameCtrl.text = profile.username;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _onUsernameTyped() {
    _debounce?.cancel();
    final uid = authService.user?.uid ?? '';
    final name = ProfileSetupRules.normalizeUsername(_usernameCtrl.text);
    if (uid.isEmpty ||
        ProfileSetupRules.validateUsername(name) != null) {
      if (mounted) setState(() => _available = null);
      return;
    }
    if (mounted) setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final free = await CloudSync.isUsernameAvailable(name, uid);
      if (!mounted) return;
      if (ProfileSetupRules.normalizeUsername(_usernameCtrl.text) !=
          name) {
        return;
      }
      setState(() {
        _checking = false;
        _available = free;
      });
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final username = ProfileSetupRules.normalizeUsername(_usernameCtrl.text);
    final nameError = ProfileSetupRules.validateDisplayName(name);
    if (nameError != null) {
      AppFeedback.heavy();
      setState(() => _error = nameError);
      return;
    }
    final userError = ProfileSetupRules.validateUsername(username);
    if (userError != null) {
      AppFeedback.heavy();
      setState(() => _error = userError);
      return;
    }
    final uid = authService.user?.uid ?? '';
    if (uid.isEmpty) {
      AppFeedback.heavy();
      setState(() => _error = tr('profile_sign_in_again'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CloudSync.claimUsername(uid: uid, username: username);
      final previous = await MemoryStore.loadProfile();
      if (previous.username.isNotEmpty && previous.username != username) {
        await CloudSync.releaseUsername(
          uid: uid,
          username: previous.username,
        );
      }
      await MemoryStore.saveProfileWithoutNotify(
        displayName: name,
        username: username,
        email: authService.email.isNotEmpty
            ? authService.email
            : previous.email,
      );
      await MemoryStore.markProfileSetupDoneWithoutNotify(uid);
      await CloudSync.pushFromLocal(uid);
      try {
        await authService.updateDisplayName(name);
      } catch (_) {
      }
      AppFeedback.medium();
      if (!mounted) return;
      widget.onDone();
    } on UsernameTakenException {
      AppFeedback.heavy();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _available = false;
        _error = tr('profile_username_taken');
      });
    } on NoConnectionException {
      AppFeedback.heavy();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr('profile_no_connection');
      });
    } catch (e) {
      AppFeedback.heavy();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is StateError ? e.message : tr('profile_no_connection');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.hairline,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUserCircle,
                        color: context.inkText,
                        size: 32,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('profile_setup_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('profile_setup_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedText, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _Label(label: tr('profile_name_label')),
                    const SizedBox(height: 6),
                    _Field(
                      controller: _nameCtrl,
                      hint: tr('profile_name_hint'),
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 14),
                    _Label(label: tr('profile_username_label')),
                    const SizedBox(height: 6),
                    _Field(
                      controller: _usernameCtrl,
                      hint: tr('profile_username_hint'),
                      prefix: '@',
                      enabled: !_busy,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_. ]'),
                        ),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      suffix: _availabilitySuffix(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE5484D),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    EngramButton(
                      label: _busy
                          ? tr('profile_saving')
                          : tr('profile_save_continue'),
                      isLoading: _busy,
                      onPressed: _busy ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _availabilitySuffix() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_available == true) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: Color(0xFF16A34A),
          size: 20,
          strokeWidth: 2.2,
        ),
      );
    }
    if (_available == false) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCancelCircle,
          color: Color(0xFFE5484D),
          size: 20,
          strokeWidth: 2.2,
        ),
      );
    }
    return null;
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.inkText,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.enabled = true,
    this.inputFormatters,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          if (prefix != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                prefix!,
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: inputFormatters,
              style: TextStyle(color: context.inkText, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: context.mutedText, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: prefix != null ? 4 : 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}
