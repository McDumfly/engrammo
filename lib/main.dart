import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';
import 'services/env_loader.dart';
import 'services/memory_store.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/learning_path.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase: a `flutterfire configure` által legenerált
  // firebase_options.dart + natív fájlok (google-services.json,
  // GoogleService-Info.plist) alapján inicializál. Ha valamelyik
  // hiányzik vagy a platform nem támogatott, az app offline
  // módban indul tovább, nem omlik össze.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Linuxon (vagy más nem konfigurált platformon) a
    // currentPlatform dobhat: ilyenkor a natív konfiggal próbálkozunk.
    if (e is UnsupportedError) {
      try {
        await Firebase.initializeApp();
      } catch (e2) {
        debugPrint('Firebase init kihagyva (nincs konfig): $e2');
      }
    } else {
      debugPrint('Firebase init kihagyva (nincs konfig): $e');
    }
    if (kDebugMode) debugPrint('Firebase init részletek: $e');
  }
  // A `.env` beolvasása az első képkocka előtt, hogy sima
  // `flutter run` esetén is éljen a gitignore-olt kulcs.
  await EnvLoader.load();
  // Mentett téma + hangok visszatöltése az első képkocka előtt.
  await appSettings.load();
  // Belépési állapot + felhő-lehúzás az első képkocka előtt.
  await authService.init();
  // Az app a rendszer sávok (állapotsor, alsó navigáció) mögé is
  // kirajzol, így lent nem marad átlátszatlan fehér rendszersáv.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A beállítás-váltás azonnal újratölti a témát az egész appban.
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        // Átlátszó rendszersávok: az alsó navigációs sáv az app
        // háttérszínét mutatja, nem egy külön fehér csíkot. Sötét
        // módban világos, világosban sötét ikonokkal.
        final dark = appSettings.darkMode;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
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
            home: const _AuthGate(),
          ),
        );
      },
    );
  }
}

/// Belépési kapu: backenddel és kijelentkezve a belépőképernyőt
/// mutatja, egyébként (belépve, vendégként vagy offline) az appot.
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

/// Induló útválasztó: első belépéskor (nincs szintmérő-eredmény és
/// az onboarding sincs pipálva) a bemutató + szintmérő jön fel,
/// egyébként egyből a tanulási útvonal.
class _StartRouter extends StatefulWidget {
  const _StartRouter();

  @override
  State<_StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<_StartRouter> {
  bool _ready = false;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    var needs = false;
    try {
      final scores = await MemoryStore.loadScores();
      final done = await MemoryStore.loadOnboardingDone();
      needs = (scores == null || scores.isEmpty) && !done;
    } catch (_) {
      needs = false;
    }
    if (!mounted) return;
    setState(() {
      _needsOnboarding = needs;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
