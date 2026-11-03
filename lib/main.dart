import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/battle_invites.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';
import 'services/bot_arena_store.dart';
import 'services/env_loader.dart';
import 'services/memory_store.dart';
import 'services/meta_ai_service.dart';

import 'package:hugeicons/hugeicons.dart';

import 'theme/app_colors.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/app_kit.dart';
import 'widgets/connectivity_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/learning_path.dart';
import 'screens/onboarding.dart';
import 'screens/profile_setup.dart';

/// Rendszer-sáv stílus sötét/világos módhoz (egyetlen igazságforrás).
SystemUiOverlayStyle overlayStyleFor(bool dark) {
  return SystemUiOverlayStyle(
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
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        debugPrint('FlutterError: ${details.exceptionAsString()}');
        FlutterError.presentError(details);
      };
      ErrorWidget.builder = (details) => const _ErrorFallback();
      await _boot();
    },
    (error, stack) {
      debugPrint('Zoned error: $error');
    },
  );
}

/// Hibahelyettesítő nézet: piros halálképernyő helyett márkázott panel.
/// Az ErrorWidget.builder MaterialApp nélkül is futhat, ezért nincs
/// Theme-függés: a színeket a brightness alapján választjuk, a szöveget
/// pedig a tr() tiszta map-keresésével (sosem dob).
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();

  @override
  Widget build(BuildContext context) {
    ThemeData theme;
    try {
      theme = Theme.of(context);
    } catch (_) {
      theme = ThemeData.fallback();
    }
    final dark = theme.brightness == Brightness.dark;
    final card = dark ? AppTheme.darkCard : paper;
    final inkColor = dark ? AppTheme.darkOnSurface : ink;
    final mutedColor = dark ? AppTheme.darkOnSurfaceVariant : muted;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: card,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: coral.withValues(alpha: 0.12),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: coral,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('error_fallback_title'),
                    style: AppText.heading.copyWith(color: inkColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('error_fallback_body'),
                    style: AppText.caption.copyWith(color: mutedColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _boot() async {
  // Az app nem forgatható: álló (portrait) nézetre rögzítve.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  SystemChrome.setSystemUIOverlayStyle(overlayStyleFor(dark));
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
        final overlay = overlayStyleFor(dark);
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
            scrollBehavior: const AppScrollBehavior(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.2,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
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
        final showingApp = authService.showApp;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(showingApp ? 'app' : 'auth'),
            child: showingApp ? const _StartRouter() : const AuthScreen(),
          ),
        );
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
  bool _dirty = false;

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
    if (!_ready) return;
    if (_resolving) {
      _dirty = true;
      return;
    }
    _resolve();
  }

  Future<void> _resolve() async {
    if (_resolving) return;
    _resolving = true;
    _dirty = false;
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
    if (_dirty) {
      _resolve();
      return;
    }
    if (_ready && _needsOnboarding == needs && _needsSetup == setup) return;
    setState(() {
      _needsOnboarding = needs;
      _needsSetup = setup;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String stateKey;
    final Widget child;
    if (!_ready) {
      stateKey = 'loading';
      child = const Scaffold(body: AppSplash());
    } else if (_needsSetup) {
      stateKey = 'setup';
      child = ProfileSetupScreen(
        onDone: () {
          if (!mounted) return;
          setState(() => _needsSetup = false);
        },
      );
    } else if (_needsOnboarding) {
      stateKey = 'onboarding';
      child = OnboardingPage(
        onDone: () {
          if (!mounted) return;
          setState(() => _needsOnboarding = false);
        },
      );
    } else {
      stateKey = 'home';
      child = const LearningPathPage();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
