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
      'No Firebase backend: run `flutterfire configure` first.';
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

  /// Névtelen Firebase-munkamenet: van uid (megy a felhő-szinkron),
  /// de nincs megadva Google/email adat.
  bool get isAnonymous => _user?.isAnonymous ?? false;

  /// Valódi, megmaradó fiók (Google vagy email/jelszó).
  bool get isPermanentAccount => signedIn && !isAnonymous;

  /// A profil mutatja a bejelentkezési kártyát: backend van, de nincs
  /// megmaradó fiók (helyi vendég vagy névtelen Firebase-felhasználó).
  bool get needsAccountNudge => _backendAvailable && !isPermanentAccount;

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

  /// Belépés fiók nélkül: backend esetén névtelen Firebase-munkamenet
  /// (azonnali uid, a felhő-szinkron ugyanúgy megy, mint bejelentkezve).
  /// Ha a névtelen belépés nincs bekapcsolva a konzolon vagy nincs net,
  /// csendben helyi vendégmódba esik vissza (pontok a készüléken).
  Future<void> continueAsGuest() => _run(() async {
    if (signedIn) {
      _guestMode = false;
      return;
    }
    if (_backendAvailable) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        _setUser(cred.user);
        _guestMode = false;
        if (_user != null) await CloudSync.pullToLocal(_user!.uid);
        return;
      } catch (_) {
        // Névtelen belépés nem megy: helyi vendégként folytatjuk.
      }
    }
    _guestMode = true;
  });

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

  /// Névtelen munkamenet megmaradó fiókká alakítása.
  ///
  /// Ha most névtelen a felhasználó, az új adatot hozzákötjük a
  /// meglévő fiókhoz ([linkWithCredential]), így az uid — és vele a
  /// `users/{uid}` felhő-dokumentum — változatlan marad. Ütközéskor
  /// (az adat már egy másik fiókhoz tartozik) sima belépésre esünk
  /// vissza: ilyenkor a felhő nyer (mint eddig), az árva névtelen
  /// dokumentumot best-effort töröljük.
  Future<void> _linkOrFresh({
    required AuthCredential newCredential,
    required Future<UserCredential> Function() freshSignIn,
  }) async {
    final anon = _user;
    if (anon == null || !anon.isAnonymous) {
      final cred = await freshSignIn();
      _setUser(cred.user);
      _guestMode = false;
      if (_user != null) await CloudSync.pullToLocal(_user!.uid);
      return;
    }
    try {
      final linked = await anon.linkWithCredential(newCredential);
      _setUser(linked.user);
      _guestMode = false;
      // Ugyanaz az uid maradt: a helyi profilmezők (név, email)
      // felkerülnek a meglévő dokumentumba.
      if (_user != null) await CloudSync.pushFromLocal(_user!.uid);
      return;
    } on FirebaseAuthException catch (e) {
      const fallbackCodes = {
        'credential-already-in-use',
        'email-already-in-use',
        'requires-recent-login',
      };
      if (!fallbackCodes.contains(e.code)) rethrow;
    }
    final oldUid = anon.uid;
    final cred = await freshSignIn();
    _setUser(cred.user);
    _guestMode = false;
    if (_user != null) {
      await CloudSync.pullToLocal(_user!.uid);
      if (oldUid != _user!.uid) {
        try {
          await CloudSync.deleteUserDoc(oldUid);
        } catch (_) {
          // Árva dokumentum maradhat: nem akadályozza a belépést.
        }
      }
    }
  }

  Future<void> signInWithGoogle() => _run(() async {
    _requireBackend();
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
      // Már inicializálva: mehet tovább.
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google sign-in is not available on this platform.');
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('No Google token received.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _linkOrFresh(
      newCredential: credential,
      freshSignIn: () =>
          FirebaseAuth.instance.signInWithCredential(credential),
    );
  });

  Future<void> signInWithEmail(String email, String password) => _run(() async {
    _requireBackend();
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await _linkOrFresh(
      newCredential: credential,
      freshSignIn: () => FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    // A Firebase Auth-beli profilnév menjen át a helyi profilba,
    // hogy a profiloldal ne maradjon üres. (A felhő-lehúzást a
    // [_linkOrFresh] már elvégezte, nem ismételjük.)
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
  });

  /// Regisztráció emaillel + jelszóval. A megjelenő nevet a Firebase
  /// Auth profilba és a helyi profilba is elmenti.
  Future<void> registerWithEmail(
    String displayName,
    String email,
    String password,
  ) => _run(() async {
    _requireBackend();
    // Névtelen munkamenetből az adat hozzákötődik a meglévő
    // uid-hez, így a felhő-dokumentum is megmarad.
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await _linkOrFresh(
      newCredential: credential,
      freshSignIn: () => FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
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
    if (u == null) throw StateError('Please sign in first.');
    await u.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    _requireBackend();
    final u = _user;
    if (u == null) throw StateError('Please sign in first.');
    await u.updatePassword(newPassword);
  }

  /// Fiók törlése: felhő-dokumentum + Auth-fiók, majd a fiókhoz
  /// kötött helyi adatok célzott törlése és kijelentkezés.
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
    // A törölt fiók adatai nem maradhatnak a készüléken — de csak a
    // fiókhoz kötöttek (profil, pontok, haladás); a széria és a
    // beállítások eszköz-szintűek, azok megmaradnak.
    await MemoryStore.clearAccountData();
    _setUser(null);
    _guestMode = false;
  });

  Future<void> signOut() => _run(() async {
    if (_backendAvailable) {
      // Névtelen fiók: kijelentkezéskor töröljük a Firebase-fiókot
      // és a felhő-dokumentumot, hogy ne maradjon árva adat. A helyi
      // mentés a készüléken megmarad, új vendég-belépéskor visszaszinkronizálódik.
      final u = _user;
      if (u != null && u.isAnonymous) {
        try {
          await CloudSync.deleteUserDoc(u.uid);
        } catch (_) {}
        try {
          await u.delete();
        } catch (_) {}
      }
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

  /// Emberi hibaüzenet a Firebase Auth kivételekből (angolul, mert
  /// a teljes felület angol).
  static String messageFor(Object e) {
    if (e is AuthBackendUnavailable) return e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered — please sign in.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password too weak (min. 6 characters).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password.';
        case 'user-disabled':
          return 'This account is disabled.';
        case 'network-request-failed':
          return 'No connection — try again later.';
        case 'requires-recent-login':
          return 'For safety, sign in again, then retry.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in the Firebase console.';
      }
      return e.message ?? 'Sign-in error (${e.code}).';
    }
    if (e is StateError) return e.message;
    return 'Unexpected error: $e';
  }
}

/// Az egész app által figyelt, közös belépési példány.
final authService = AuthService();
