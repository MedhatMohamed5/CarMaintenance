import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// [AuthService] backed by Firebase Authentication.
///
/// Every Firebase type stops here. The rest of the app sees [AppUser] and
/// [AuthFailure], so swapping the provider — or standing it down entirely, as
/// [LocalAuthService] does — touches this file and nothing else.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      // The credential's snapshot predates the rename, so it is re-read rather
      // than returned stale — otherwise Settings shows the email until the
      // next launch.
      await credential.user?.reload();
    }
    return credential;
  });

  /// google_sign_in 7.x requires an explicit `initialize()` before any call,
  /// and it must happen once per process rather than per sign-in attempt.
  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  bool _googleReady = false;

  @override
  Future<AppUser> signInWithGoogle() async {
    // The web plugin has no `authenticate()` — a browser sign-in goes through
    // Firebase's own popup instead, which is the supported path there.
    if (kIsWeb) {
      return _guard(() => _auth.signInWithPopup(fb.GoogleAuthProvider()));
    }

    try {
      await _ensureGoogleReady();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthException(AuthFailure.unknown);

      return await _guard(
        () => _auth.signInWithCredential(
          fb.GoogleAuthProvider.credential(idToken: idToken),
        ),
      );
    } on GoogleSignInException catch (e) {
      // Backing out of the sheet is a decision, not a failure: the caller
      // shows nothing for it.
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<AppUser> signInAnonymously() => _guard(_auth.signInAnonymously);

  @override
  Future<void> signOut() async {
    // Firebase first, so the app is signed out even if the Google plugin
    // throws — a stale Google session is harmless, a stale Firebase one is not.
    await _auth.signOut();
    if (kIsWeb) return;
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Never initialised, or no Google session to end.
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_failureOf(e.code));
    }
  }

  /// Runs a Firebase call and translates its failures at the boundary.
  Future<AppUser> _guard(Future<fb.UserCredential> Function() call) async {
    try {
      final credential = await call();
      final user = _map(credential.user ?? _auth.currentUser);
      if (user == null) throw const AuthException(AuthFailure.unknown);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_failureOf(e.code));
    } on AuthException {
      rethrow;
    } on Object {
      // A missing plugin on desktop, a placeholder project, a malformed
      // response: all of them mean the same thing to the caller.
      throw const AuthException(AuthFailure.unknown);
    }
  }

  static AppUser? _map(fb.User? user) => user == null
      ? null
      : AppUser(
          id: user.uid,
          email: user.email,
          displayName: user.displayName,
          isAnonymous: user.isAnonymous,
        );

  /// Firebase error codes, reduced to the ones the app can say something
  /// useful about.
  ///
  /// `invalid-credential` covers what older SDKs split into wrong-password and
  /// user-not-found; both are mapped to the same answer because Firebase
  /// deliberately stopped distinguishing them, and telling a user which half
  /// was wrong is an account-enumeration leak anyway.
  static AuthFailure _failureOf(String code) => switch (code) {
    'invalid-email' => AuthFailure.invalidEmail,
    'wrong-password' || 'invalid-credential' => AuthFailure.wrongPassword,
    'user-not-found' => AuthFailure.userNotFound,
    'email-already-in-use' => AuthFailure.emailInUse,
    'weak-password' => AuthFailure.weakPassword,
    'network-request-failed' => AuthFailure.network,
    'configuration-not-found' ||
    'api-key-not-valid' ||
    'app-not-authorized' => AuthFailure.notConfigured,
    _ => AuthFailure.unknown,
  };
}

/// The stand-in used when Firebase is not configured.
///
/// **Reports "not configured" rather than pretending to sign anyone in.** A
/// fake local user would have let the app act signed-in and quietly write data
/// nowhere, which is worse than a clear refusal: the driver would find out at
/// the point they expect their history on a second device.
class LocalAuthService implements AuthService {
  const LocalAuthService();

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async => throw const AuthException(AuthFailure.notConfigured);

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async => throw const AuthException(AuthFailure.notConfigured);

  @override
  Future<AppUser> signInWithGoogle() async =>
      throw const AuthException(AuthFailure.notConfigured);

  @override
  Future<AppUser> signInAnonymously() async =>
      throw const AuthException(AuthFailure.notConfigured);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async =>
      throw const AuthException(AuthFailure.notConfigured);
}
