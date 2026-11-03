import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart' show error, muted;
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../widgets/google_g_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _obscure = true;
  bool _resetSent = false;
  String? _error;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    AppFeedback.heavy();
    setState(() {
      _error = AuthService.messageFor(e);
      _resetSent = false;
    });
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _resetSent = false;
    });
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!_emailPattern.hasMatch(email)) {
      return _fail(StateError(tr('auth_invalid_email')));
    }
    if (password.length < 6) {
      return _fail(StateError(tr('auth_short_password')));
    }
    try {
      if (_register) {
        await authService.registerWithEmail(_nameCtrl.text, email, password);
      } else {
        await authService.signInWithEmail(email, password);
      }
      AppFeedback.medium();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _google() async {
    setState(() {
      _error = null;
      _resetSent = false;
    });
    try {
      await authService.signInWithGoogle();
      AppFeedback.medium();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on GoogleSignInCanceled {
      return;
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _resetSent = false;
    });
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      return _fail(StateError(tr('auth_reset_prompt')));
    }
    try {
      await authService.sendPasswordReset(email);
      setState(() => _resetSent = true);
      AppFeedback.light();
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListenableBuilder(
        listenable: authService,
        builder: (context, _) => SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Push-olt útként (pl. profilból) bezárható legyen.
                    if (Navigator.of(context).canPop())
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: EngramBackButton.close(),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _register
                          ? tr('auth_create_account')
                          : tr('auth_welcome_back'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _register
                          ? tr('auth_register_subtitle')
                          : tr('auth_login_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedText, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppSegmented<bool>(
                      options: [
                        (false, tr('auth_sign_in_tab')),
                        (true, tr('auth_register_tab')),
                      ],
                      value: _register,
                      onChanged: (v) => setState(() {
                        _register = v;
                        _error = null;
                        _resetSent = false;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_register) ...[
                      _Field(
                        controller: _nameCtrl,
                        hint: tr('auth_display_name_hint'),
                        enabled: !authService.busy,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _Field(
                      controller: _emailCtrl,
                      hint: tr('auth_email_hint'),
                      keyboard: TextInputType.emailAddress,
                      enabled: !authService.busy,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _passwordCtrl,
                      hint: tr('auth_password_hint'),
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      enabled: !authService.busy,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_resetSent) ...[
                      const SizedBox(height: 10),
                      Text(
                        tr('auth_reset_sent'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    EngramButton(
                      label: authService.busy
                          ? tr('auth_please_wait')
                          : (_register
                                ? tr('auth_create_button')
                                : tr('auth_sign_in_button')),
                      onPressed: authService.busy ? null : () => _submit(),
                      isLoading: authService.busy,
                    ),
                    if (!_register) ...[
                      const SizedBox(height: 4),
                      EngramTextButton(
                        label: tr('auth_forgot_password'),
                        color: muted,
                        onPressed: authService.busy ? null : _reset,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: AppDivider(thickness: 2)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            tr('auth_or'),
                            style: TextStyle(
                              color: context.mutedText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Expanded(child: AppDivider(thickness: 2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    EngramButton(
                      label: tr('auth_google_button'),
                      leading: const GoogleGLogo(size: 22),
                      variant: EngramButtonVariant.secondary,
                      onPressed: authService.busy ? null : _google,
                    ),
                    const SizedBox(height: 8),
                    EngramTextButton(
                      label: tr('auth_guest_button'),
                      color: muted,
                      onPressed: authService.busy
                          ? null
                          : () async {
                              await authService.continueAsGuest();
                              if (!context.mounted) return;
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
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
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboard;
  final bool enabled;
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboard,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      hint: hint,
      suffix: onToggleObscure == null
          ? null
          : AppIconButton(
              onTap: onToggleObscure,
              icon: obscure
                  ? HugeIcons.strokeRoundedEye
                  : HugeIcons.strokeRoundedEyeOff,
              color: context.mutedText,
            ),
    );
  }
}
