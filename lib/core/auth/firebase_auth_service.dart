import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/crash_reporter.dart';
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

  /// The project's **web** OAuth client, copied from `google-services.json`
  /// (`client_type: 3`).
  ///
  /// **Passed explicitly rather than left to the plugin to find.** Android's
  /// Credential Manager needs a server client ID to return an ID token, and
  /// with none supplied the plugin looks up the `default_web_client_id` string
  /// resource by name, through `Resources.getIdentifier`. That is a reflective
  /// lookup of a generated resource, in a release build that shrinks resources
  /// — a chain with no compile-time check anywhere along it, whose failure
  /// mode is a sign-in that works in debug and not in release. Naming the value
  /// here removes the lookup from the path entirely.
  ///
  /// Not a secret: it identifies the project to Google, ships inside every
  /// build already, and is worthless without a certificate registered against
  /// it. Overridable for a build against a different Firebase project:
  ///
  ///     flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=…
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '718762511471-cv5hkvpgq5h9jil478m3d9c2l8f1suc0.apps.googleusercontent.com',
  );

  /// google_sign_in 7.x requires an explicit `initialize()` before any call,
  /// and it must happen once per process rather than per sign-in attempt.
  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
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
      _traceGoogle('authenticate: requesting credential');

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      // **Authenticated, but with nothing to hand Firebase.** Not a cancel and
      // not an exception: the sheet completed and returned an account whose ID
      // token is absent, which on Android means the credential came back
      // without the server client ID's audience — the same misconfiguration a
      // configuration error names, arriving down a path that throws nothing.
      if (idToken == null) {
        _reportGoogleFailure(
          StateError('Google returned an account with no ID token'),
          StackTrace.current,
          code: 'null-id-token',
          detail:
              'authenticated as ${_redact(account.email)} but idToken was null',
        );
        throw const AuthException(AuthFailure.unknown);
      }

      _traceGoogle('authenticate: got ID token, exchanging with Firebase');
      return await _guard(
        () => _auth.signInWithCredential(
          fb.GoogleAuthProvider.credential(idToken: idToken),
        ),
      );
    } on GoogleSignInException catch (e, stack) {
      // **A cancel is not always the driver's.** Credential Manager reports a
      // token it refused to issue *after* an account was picked — an app
      // signing certificate with no OAuth client, most often — as a
      // `GetCredentialCancellationException`, which arrives here as
      // `canceled`, carrying Google's own message ("[16] Account reauth
      // failed."). Treating every cancel as a decision made that failure
      // invisible twice over: the driver saw nothing happen after choosing
      // their account, and nothing was recorded anywhere.
      //
      // The screen still says nothing — it may genuinely have been the driver
      // backing out — but the message is kept and sent as a warning, so a
      // refusal is readable from Sentry instead of guessed at.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _reportGoogleFailure(
          e,
          stack,
          code: e.code.name,
          detail: [
            if (e.description != null) e.description,
            if (e.details != null) '${e.details}',
          ].join(' · '),
          warning: true,
        );
        throw const AuthException(AuthFailure.cancelled);
      }

      _reportGoogleFailure(
        e,
        stack,
        code: e.code.name,
        detail: [
          if (e.description != null) e.description,
          if (e.details != null) '${e.details}',
        ].join(' · '),
      );
      throw const AuthException(AuthFailure.unknown);
    } on PlatformException catch (e, stack) {
      // **Not the Google plugin's path.** `google_sign_in` 7.x converts every
      // platform failure to a `GoogleSignInException` before it crosses the
      // channel, so a raw `PlatformException` here came from `firebase_auth`
      // exchanging the credential — a different plugin, its own channel, and
      // one that does carry a string `code` worth logging verbatim.
      _reportGoogleFailure(
        e,
        stack,
        code: e.code,
        detail: [
          e.message,
          if (e.details != null) '${e.details}',
        ].whereType<String>().join(' · '),
      );
      throw const AuthException(AuthFailure.unknown);
    } on AuthException {
      rethrow;
    } on Object catch (e, stack) {
      _reportGoogleFailure(e, stack, code: e.runtimeType.toString());
      throw const AuthException(AuthFailure.unknown);
    }
  }

  /// One place where a failed Google sign-in is written down, three ways.
  ///
  /// **The three destinations answer different questions.** `developer.log`
  /// puts it in the IDE's structured log with a name to filter on;
  /// `debugPrint` survives `flutter logs` and `adb logcat` on a device with no
  /// debugger attached, which is where a release-only failure is actually
  /// caught; Sentry is the only one that reaches a build already on someone
  /// else's phone.
  ///
  /// **The server client ID is logged with every failure**, because the two
  /// things that break Google sign-in in release builds — a certificate the
  /// backend does not know, and the wrong OAuth client — are indistinguishable
  /// from the error text alone. It is not a secret; it ships in every build.
  void _reportGoogleFailure(
    Object error,
    StackTrace stack, {
    required String code,
    String? detail,
    bool warning = false,
  }) {
    final where = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final summary =
        'google-sign-in failed [$code] on $where '
        'serverClientId=$_serverClientId'
        '${detail == null || detail.isEmpty ? '' : ' — $detail'}';

    developer.log(
      summary,
      name: _logName,
      level: warning ? 900 : 1000, // WARNING : SEVERE
      error: error,
      stackTrace: stack,
    );
    debugPrint('[$_logName] $summary');

    CrashReporter.recordError(
      error,
      stack,
      reason: summary,
      tags: {
        'action': 'google-sign-in',
        'google_sign_in.code': code,
        'google_sign_in.platform': where,
      },
      warning: warning,
    );
  }

  /// Progress through the flow.
  ///
  /// **Printed in release too, and kept as a breadcrumb.** The failure this
  /// exists for only happens on a Play-signed build, where `developer.log`
  /// reaches nothing and a debug-only print is compiled out — so a sign-in
  /// that stalled left no trace of how far it got. Two short lines per sign-in
  /// in logcat is a fair price, and as breadcrumbs they ride along on whatever
  /// event follows, which is where they are read.
  static void _traceGoogle(String message) {
    developer.log(message, name: _logName);
    debugPrint('[$_logName] $message');
    CrashReporter.log('$_logName: $message');
  }

  static const String _logName = 'auth.google';

  /// Enough of an address to tell two accounts apart in a log, not enough to
  /// be one. Diagnostics are not a place to write down a user's email.
  static String _redact(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '***';
    return '${email[0]}***${email.substring(at)}';
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
