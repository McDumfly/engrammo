import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart' show error, muted;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
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
  bool _guestBusy = false;
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
    final message = AuthService.messageFor(e);
    setState(() {
      _error = message;
      _resetSent = false;
    });
    showAppToast(context, message, kind: ToastKind.error);
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

  Future<void> _guest() async {
    if (authService.busy || _guestBusy) return;
    AppFeedback.light();
    setState(() => _guestBusy = true);
    try {
      await authService.continueAsGuest();
    } finally {
      if (mounted) setState(() => _guestBusy = false);
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * t,
                            child: child,
                          ),
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon_foreground.png',
                          width: 72,
                          color: context.inkText,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Engrammo',
                      textAlign: TextAlign.center,
                      style: AppText.display.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('auth_tagline'),
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: context.mutedText),
                    ),
                    const SizedBox(height: 32),
                    EngramButton(
                      label: tr('auth_guest_cta'),
                      onPressed: (authService.busy || _guestBusy)
                          ? null
                          : _guest,
                      isLoading: _guestBusy,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('auth_guest_hint'),
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: context.mutedText),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: AppDivider(thickness: 2)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            tr('auth_or'),
                            style: AppText.caption.copyWith(
                              color: context.mutedText,
                            ),
                          ),
                        ),
                        const Expanded(child: AppDivider(thickness: 2)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                        enabled: !(authService.busy || _guestBusy),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _Field(
                      controller: _emailCtrl,
                      hint: tr('auth_email_hint'),
                      keyboard: TextInputType.emailAddress,
                      enabled: !(authService.busy || _guestBusy),
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _passwordCtrl,
                      hint: tr('auth_password_hint'),
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      enabled: !(authService.busy || _guestBusy),
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
                        style: AppText.caption.copyWith(color: context.inkText),
                      ),
                    ],
                    const SizedBox(height: 14),
                    EngramButton(
                      label: (authService.busy && !_guestBusy)
                          ? tr('auth_please_wait')
                          : (_register
                                ? tr('auth_create_button')
                                : tr('auth_sign_in_button')),
                      variant: EngramButtonVariant.secondary,
                      onPressed: (authService.busy || _guestBusy)
                          ? null
                          : () => _submit(),
                      isLoading: authService.busy && !_guestBusy,
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
                            style: AppText.caption.copyWith(
                              color: context.mutedText,
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
              size: 32,
            ),
    );
  }
}
