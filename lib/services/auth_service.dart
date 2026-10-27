import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_settings.dart';
import 'cloud_sync.dart';
import 'memory_store.dart';

/// Nincs Firebase-backend: a `flutterfire configure` még nem futott le,
/// vagy hiányzik a platform-konfig. Ilyenkor az app offline módban megy.
class AuthBackendUnavailable implements Exception {
  const AuthBackendUnavailable();

  @override
  String toString() =>
      'Nincs Firebase-backend: futtasd a `flutterfire configure` parancsot.';
}

/// Beléptetés + munkamenet egy helyen.
///
/// Backend nélkül ([backendAvailable] == false) minden belépési kísérlet
/// [AuthBackendUnavailable]-t dob, az app pedig vendég/offline módban
/// használható tovább. Bejelentkezve a felhőből egyszer visszatöltjük
/// a mentést ([CloudSync.pullToLocal]), íráskor pedig a [MemoryStore]
/// `onChanged` horgán át automatikusan feltöltünk.
class AuthService extends ChangeNotifier {
  bool _backendAvailable = false;
  bool _guestMode = false;
  bool _busy = false;
  User? _user;
  StreamSubscription<User?>? _sub;

  bool get backendAvailable => _backendAvailable;
  bool get guestMode => _guestMode;
  bool get busy => _busy;
  User? get user => _user;
  bool get signedIn => _user != null;

  /// Belépve, vendégként vagy backend nélkül is mehet az app.
  bool get showApp => signedIn || _guestMode || !_backendAvailable;

  bool get isGoogleUser =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  String get email => _user?.email ?? '';

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        _backendAvailable = false;
      } else {
        _backendAvailable = true;
        _setUser(FirebaseAuth.instance.currentUser);
        _sub = FirebaseAuth.instance.authStateChanges().listen((u) async {
          _setUser(u);
          if (u != null) {
            _guestMode = false;
            await CloudSync.pullToLocal(u.uid);
          }
          notifyListeners();
        });
        if (_user != null) await CloudSync.pullToLocal(_user!.uid);
      }
    } catch (_) {
      _backendAvailable = false;
    }
    // A szinkron-horgok backend nélkül is ártalmatlanok (azonnal visszatérnek).
    MemoryStore.onChanged = () => CloudSync.pushNow();
    appSettings.onChanged = () => CloudSync.pushNow();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _requireBackend() {
    if (!_backendAvailable) throw const AuthBackendUnavailable();
  }

  void _setUser(User? u) {
    _user = u;
    CloudSync.currentUid = u?.uid;
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await work();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Belépés fiók nélkül (a 3. kérdésre adott "névtelen" helyett is jó
  /// kipróbálásra; a pontok csak a készüléken maradnak).
  Future<void> continueAsGuest() async {
    _guestMode = true;
    notifyListeners();
  }

  void exitGuest() {
    _guestMode = false;
    notifyListeners();
  }

  Future<void> signInAnonymously() => _run(() async {
    _requireBackend();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    _setUser(cred.user);
    _guestMode = false;
    if (_user != null) await CloudSync.pullToLocal(_user!.uid);
  });

  Future<void> signInWithGoogle() => _run(() async {
    _requireBackend();
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
      // Már inicializálva: mehet tovább.
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Ezen a platformon nem megy a Google-belépés.');
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Nem érkezett Google-token.');
    }
    final cred = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    _setUser(cred.user);
    _guestMode = false;
    if (_user != null) await CloudSync.pullToLocal(_user!.uid);
  });

  Future<void> signInWithEmail(String email, String password) => _run(() async {
    _requireBackend();
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _setUser(cred.user);
    _guestMode = false;
    // A Firebase Auth-beli profilnév menjen át a helyi profilba,
    // hogy a profiloldal ne maradjon üres.
    final name = _user?.displayName ?? '';
    if (name.isNotEmpty) {
      final current = await MemoryStore.loadProfile();
      if (current.displayName.isEmpty) {
        await MemoryStore.saveProfile(
          displayName: name,
          username: current.username,
          email: _user?.email ?? current.email,
        );
      }
    }
    if (_user != null) await CloudSync.pullToLocal(_user!.uid);
  });

  /// Regisztráció emaillel + jelszóval. A megjelenő nevet a Firebase
  /// Auth profilba és a helyi profilba is elmenti.
  Future<void> registerWithEmail(
    String displayName,
    String email,
    String password,
  ) => _run(() async {
    _requireBackend();
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _setUser(cred.user);
    _guestMode = false;
    final name = displayName.trim();
    if (name.isNotEmpty) {
      await _user?.updateDisplayName(name);
      final current = await MemoryStore.loadProfile();
      await MemoryStore.saveProfile(
        displayName: name,
        username: current.username,
        email: _user?.email ?? current.email,
      );
      await _user?.reload();
      _setUser(FirebaseAuth.instance.currentUser);
    }
    if (_user != null) await CloudSync.pushFromLocal(_user!.uid);
  });

  Future<void> sendPasswordReset(String email) async {
    _requireBackend();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  /// Megjelenő név frissítése a Firebase-profilban is.
  Future<void> updateDisplayName(String name) async {
    final u = _user;
    if (u == null) return;
    await u.updateDisplayName(name.trim().isEmpty ? null : name.trim());
    await u.reload();
    _setUser(FirebaseAuth.instance.currentUser);
    notifyListeners();
  }

  /// Email-csere ellenőrző levéllel (a Firebase csak így engedi v7-ben).
  /// A cím a levélben lévő linkre kattintva cserélődik.
  Future<void> updateEmailAddress(String newEmail) async {
    _requireBackend();
    final u = _user;
    if (u == null) throw StateError('Ehhez jelentkezz be.');
    await u.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    _requireBackend();
    final u = _user;
    if (u == null) throw StateError('Ehhez jelentkezz be.');
    await u.updatePassword(newPassword);
  }

  /// Fiók törlése: felhő-dokumentum + Auth-fiók, majd helyi kijelentkezés.
  /// Friss belépést igényelhet — ilyenkor kivételt dob.
  Future<void> deleteAccount() => _run(() async {
    final u = _user;
    if (u == null) {
      _guestMode = false;
      notifyListeners();
      return;
    }
    if (_backendAvailable) {
      try {
        await CloudSync.deleteUserDoc(u.uid);
      } catch (_) {
        // A dokumentum törlése nem akadályozza a fiók törlését.
      }
      await u.delete();
    }
    _setUser(null);
    _guestMode = false;
  });

  Future<void> signOut() => _run(() async {
    if (_backendAvailable) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Offline is lehet kijelentkezni: a helyi állapot ürül.
      }
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Nem volt Google-munkamenet.
      }
    }
    _setUser(null);
    _guestMode = false;
  });

  /// Emberi hibaüzenet a Firebase Auth kivételekből.
  static String messageFor(Object e) {
    if (e is AuthBackendUnavailable) return e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Ez az email már regisztrálva van — jelentkezz be.';
        case 'invalid-email':
          return 'Érvénytelen email-cím.';
        case 'weak-password':
          return 'Túl gyenge jelszó (min. 6 karakter).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Hibás email vagy jelszó.';
        case 'user-disabled':
          return 'Ez a fiók le van tiltva.';
        case 'network-request-failed':
          return 'Nincs net — próbáld újra később.';
        case 'requires-recent-login':
          return 'Biztonságból jelentkezz be újra, majd próbáld megint.';
        case 'operation-not-allowed':
          return 'Ez a belépési mód nincs bekapcsolva a Firebase-konzolon.';
      }
      return e.message ?? 'Belépési hiba (${e.code}).';
    }
    if (e is StateError) return e.message;
    return 'Váratlan hiba: $e';
  }
}

/// Az egész app által figyelt, közös belépési példány.
final authService = AuthService();
