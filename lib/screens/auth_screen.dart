import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/google_g_logo.dart';

/// Belépő / regisztrációs képernyő.
///
/// Email+jelszó (bejelentkezés és regisztráció), Google-belépés és
/// fiók nélküli folytatás. Backend nélkül az [AuthGate] eleve nem ezt
/// mutatja; ha mégis ide jutna, a gombok hibaüzenetet adnak.
/// A profil bejelentkezési kártyájáról útvonalként is nyitható:
/// ilyenkor sikeres belépés után visszalép a profilra.
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

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _resetSent = false;
    });
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!email.contains('@')) {
      return _fail(StateError('Adj meg egy érvényes email-címet.'));
    }
    if (password.length < 6) {
      return _fail(StateError('A jelszó legalább 6 karakter legyen.'));
    }
    try {
      if (_register) {
        await authService.registerWithEmail(_nameCtrl.text, email, password);
      } else {
        await authService.signInWithEmail(email, password);
      }
      AppFeedback.medium();
      // Útvonalként nyitva (profilkártya): vissza a profilra.
      // Kapuként (gyökér) a canPop hamis, a kapu magától vált.
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
    } catch (e) {
      // A felhasználó által megszakított Google-folyamat nem hiba.
      final msg = '$e';
      if (msg.contains('canceled')) return;
      _fail(e);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _resetSent = false;
    });
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      return _fail(StateError('Írd be az emailed, arra megy a levél.'));
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
                    const SizedBox(height: 12),
                    Text(
                      _register ? 'Create account' : 'Welcome back',
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
                          ? 'Your scores, streak and avatar sync to the cloud.'
                          : 'Pick up where you left off — on any device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedText, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _Segment(
                      register: _register,
                      onChanged: (v) => setState(() {
                        _register = v;
                        _error = null;
                        _resetSent = false;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_register) ...[
                      _Field(controller: _nameCtrl, hint: 'Display name'),
                      const SizedBox(height: 10),
                    ],
                    _Field(
                      controller: _emailCtrl,
                      hint: 'you@example.com',
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _passwordCtrl,
                      hint: 'Password (min. 6 characters)',
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
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
                    if (_resetSent) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Reset email sent — check your inbox.',
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
                          ? 'PLEASE WAIT…'
                          : (_register ? 'CREATE ACCOUNT' : 'SIGN IN'),
                      onPressed: authService.busy ? null : () => _submit(),
                      isLoading: authService.busy,
                    ),
                    if (!_register) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: authService.busy ? null : _reset,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: context.hairline, thickness: 2),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: context.mutedText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: context.hairline, thickness: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    EngramButton(
                      label: 'CONTINUE WITH GOOGLE',
                      leading: const GoogleGLogo(size: 22),
                      variant: EngramButtonVariant.secondary,
                      onPressed: authService.busy ? null : _google,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: authService.busy
                          ? null
                          : () async {
                              await authService.continueAsGuest();
                              if (!context.mounted) return;
                              // Útvonalként nyitva: vissza oda, ahonnan jött.
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(
                        'Continue without account',
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _Segment extends StatelessWidget {
  final bool register;
  final ValueChanged<bool> onChanged;
  const _Segment({required this.register, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segBtn(
              context,
              'Sign in',
              !register,
              () => onChanged(false),
            ),
          ),
          Expanded(
            child: _segBtn(
              context,
              'Register',
              register,
              () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segBtn(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        AppFeedback.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? context.washBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? context.inkText : context.mutedText,
            fontWeight: FontWeight.w900,
            fontSize: 14,
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
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboard,
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
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: context.inkText, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: context.mutedText, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              icon: HugeIcon(
                icon: obscure
                    ? HugeIcons.strokeRoundedEye
                    : HugeIcons.strokeRoundedEyeOff,
                color: context.mutedText,
                size: 20,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}
