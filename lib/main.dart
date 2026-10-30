import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'models/battle_invites.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';
import 'services/bot_arena_store.dart';
import 'services/env_loader.dart';
import 'services/memory_store.dart';
import 'services/meta_ai_service.dart';
import 'theme/app_theme.dart';
import 'widgets/connectivity_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/learning_path.dart';
import 'screens/onboarding.dart';
import 'screens/profile_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e is UnsupportedError) {
      try {
        await Firebase.initializeApp();
      } catch (e2) {
        debugPrint('Firebase init skipped (no config): $e2');
      }
    } else {
      debugPrint('Firebase init skipped (no config): $e');
    }
    if (kDebugMode) debugPrint('Firebase init details: $e');
  }
  await EnvLoader.load();
  await MetaAIService.persistLaunchKeyIfPresent();
  await appSettings.load();
  await authService.init();
  // The offline arena (bots, league season, friends) warms up once here so
  // every tab shows live data. It never throws and degrades to empty boards.
  unawaited(botArena.ensureLoaded());
  unawaited(battleInvites.ensureLoaded());
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // The global default is transparent too, so no route can bring back a
  // thin dark divider line above the bottom exit strip.
  final dark = appSettings.darkMode;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        final dark = appSettings.darkMode;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: MaterialApp(
            title: 'Engrammo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(appSettings.languageCode),
            supportedLocales: const [Locale('en'), Locale('hu')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ConnectivityGate(child: _AuthGate()),
          ),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        if (authService.showApp) return const _StartRouter();
        return const AuthScreen();
      },
    );
  }
}

class _StartRouter extends StatefulWidget {
  const _StartRouter();

  @override
  State<_StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<_StartRouter> {
  bool _ready = false;
  bool _needsOnboarding = false;
  bool _needsSetup = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    authService.addListener(_onAuthChanged);
    _resolve();
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!_ready || _resolving) return;
    _resolve();
  }

  Future<void> _resolve() async {
    if (_resolving) return;
    _resolving = true;
    var needs = false;
    var setup = false;
    try {
      final uid = authService.user?.uid;
      if (authService.isPermanentAccount && uid != null) {
        final done = await MemoryStore.isProfileSetupDone(uid);
        if (!done) {
          final profile = await MemoryStore.loadProfile();
          if (profile.displayName.trim().isNotEmpty &&
              profile.username.trim().isNotEmpty) {
            await MemoryStore.markProfileSetupDone(uid);
          } else {
            setup = true;
          }
        }
      }
      final scores = await MemoryStore.loadScores();
      final done = await MemoryStore.loadOnboardingDone();
      needs = (scores == null || scores.isEmpty) && !done;
    } catch (_) {
      needs = false;
    }
    _resolving = false;
    if (!mounted) return;
    if (_ready && _needsOnboarding == needs && _needsSetup == setup) return;
    setState(() {
      _needsOnboarding = needs;
      _needsSetup = setup;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsSetup) {
      return ProfileSetupScreen(
        onDone: () {
          if (!mounted) return;
          setState(() => _needsSetup = false);
        },
      );
    }
    if (_needsOnboarding) {
      return OnboardingPage(
        onDone: () {
          if (!mounted) return;
          setState(() => _needsOnboarding = false);
        },
      );
    }
    return const LearningPathPage();
  }
}
