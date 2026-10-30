import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/app_localizations.dart';
import '../models/battle_invites.dart';
import 'app_settings.dart';
import 'bot_arena_store.dart';
import 'cloud_sync.dart';
import 'memory_store.dart';

class AuthBackendUnavailable implements Exception {
  const AuthBackendUnavailable();

  @override
  String toString() =>
      'No Firebase backend: run `flutterfire configure` first.';
}

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

  bool get isAnonymous => _user?.isAnonymous ?? false;

  bool get isPermanentAccount => signedIn && !isAnonymous;

  bool get needsAccountNudge => _backendAvailable && !isPermanentAccount;

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
            await _refreshArena();
          }
          notifyListeners();
        });
        if (_user != null) {
          await CloudSync.pullToLocal(_user!.uid);
          await _refreshArena();
        }
      }
    } catch (_) {
      _backendAvailable = false;
    }
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

  /// Reloads arena state from storage after a cloud pull so the league,
  /// roster, feed and invites reflect Firebase instead of stale memory.
  Future<void> _refreshArena() async {
    try {
      await botArena.refresh();
    } catch (_) {}
    try {
      await battleInvites.refresh();
    } catch (_) {}
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
        if (_user != null) {
          await CloudSync.pullToLocal(_user!.uid);
          await _refreshArena();
        }
        return;
      } catch (_) {
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
    if (_user != null) {
      await CloudSync.pullToLocal(_user!.uid);
      await _refreshArena();
    }
  });

  Future<void> _linkOrFresh({
    required AuthCredential newCredential,
    required Future<UserCredential> Function() freshSignIn,
  }) async {
    final anon = _user;
    if (anon == null || !anon.isAnonymous) {
      final cred = await freshSignIn();
      _setUser(cred.user);
      _guestMode = false;
      if (_user != null) {
        await CloudSync.pullToLocal(_user!.uid);
        await _refreshArena();
      }
      return;
    }
    try {
      final linked = await anon.linkWithCredential(newCredential);
      _setUser(linked.user);
      _guestMode = false;
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
      await _refreshArena();
      if (oldUid != _user!.uid) {
        try {
          await CloudSync.deleteUserDoc(oldUid);
        } catch (_) {
        }
      }
    }
  }

  Future<void> signInWithGoogle() => _run(() async {
    _requireBackend();
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError(tr('auth_google_unavailable'));
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(tr('auth_no_google_token'));
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

  Future<void> registerWithEmail(
    String displayName,
    String email,
    String password,
  ) => _run(() async {
    _requireBackend();
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

  Future<void> updateDisplayName(String name) async {
    final u = _user;
    if (u == null) return;
    await u.updateDisplayName(name.trim().isEmpty ? null : name.trim());
    await u.reload();
    _setUser(FirebaseAuth.instance.currentUser);
    notifyListeners();
  }

  Future<void> updateEmailAddress(String newEmail) async {
    _requireBackend();
    final u = _user;
    if (u == null) throw StateError(tr('auth_sign_in_first'));
    await u.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    _requireBackend();
    final u = _user;
    if (u == null) throw StateError(tr('auth_sign_in_first'));
    await u.updatePassword(newPassword);
  }

  Future<void> deleteAccount() => _run(() async {
    final u = _user;
    if (u == null) {
      _guestMode = false;
      notifyListeners();
      return;
    }
    if (_backendAvailable) {
      try {
        final profile = await MemoryStore.loadProfile();
        if (profile.username.isNotEmpty) {
          await CloudSync.releaseUsername(
            uid: u.uid,
            username: profile.username,
          );
        }
      } catch (_) {
      }
      try {
        await CloudSync.deleteUserDoc(u.uid);
      } catch (_) {
      }
      await u.delete();
    }
    await MemoryStore.clearAccountData();
    _setUser(null);
    _guestMode = false;
    await _refreshArena();
  });

  Future<void> signOut() => _run(() async {
    if (_backendAvailable) {
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
      }
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
      }
    }
    _setUser(null);
    _guestMode = false;
  });

  static String messageFor(Object e) {
    if (e is AuthBackendUnavailable) return tr('auth_no_backend');
    if (e is NoConnectionException) return tr('auth_no_connection');
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return tr('auth_email_in_use');
        case 'invalid-email':
          return tr('auth_invalid_email_addr');
        case 'weak-password':
          return tr('auth_weak_password');
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return tr('auth_wrong_credentials');
        case 'user-disabled':
          return tr('auth_account_disabled');
        case 'network-request-failed':
          return tr('auth_no_connection');
        case 'requires-recent-login':
          return tr('auth_recent_login');
        case 'operation-not-allowed':
          return tr('auth_method_disabled');
      }
      return e.message ?? tr('auth_error_code', {'code': e.code});
    }
    if (e is StateError) return e.message;
    return tr('auth_unexpected', {'detail': '$e'});
  }
}

final authService = AuthService();
