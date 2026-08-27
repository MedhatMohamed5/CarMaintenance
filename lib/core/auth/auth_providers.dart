import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_bootstrap.dart';
import '../firebase/firebase_config.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';

/// Whether this build can talk to Firebase at all.
///
/// Two conditions, and both must hold: the platform has generated credentials,
/// and initialisation actually succeeded with them. The first alone is not
/// enough — a desktop build has no options at all — and the second alone would
/// let a stale `_available` flag outlive a failed init.
///
/// This is what the sign-in screen checks before offering to sign anyone in,
/// so an unconfigured target says "cloud sync is not set up here" instead of
/// failing at the button with a Firebase error code the driver cannot act on.
final cloudAvailableProvider = Provider<bool>(
  (ref) => FirebaseConfig.isSupportedPlatform && FirebaseBootstrap.isAvailable,
);

final authServiceProvider = Provider<AuthService>((ref) {
  if (!ref.watch(cloudAvailableProvider)) return const LocalAuthService();
  return FirebaseAuthService(fb.FirebaseAuth.instance);
});

/// The signed-in user, or null.
///
/// A stream rather than a one-off read: Firebase resolves the persisted session
/// asynchronously at startup, and a token can expire or be revoked mid-session.
/// Anything that reads the user must react to it changing, or it will keep
/// writing to the previous account's tree.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// The current user id, or null while signed out or still resolving.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.id,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(currentUserIdProvider) != null,
);

/// Controls sign-in, sign-up and sign-out for the UI.
///
/// Returns `bool` rather than throwing at the call site, in the same shape as
/// every other controller here: the screen asks whether it worked and reads
/// [lastFailure] for what to say if it did not.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthFailure? _failure;

  AuthFailure? get lastFailure => _failure;

  Future<bool> signIn({required String email, required String password}) =>
      _run(
        () => ref
            .read(authServiceProvider)
            .signInWithEmail(email: email, password: password),
      );

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) => _run(
    () => ref
        .read(authServiceProvider)
        .registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        ),
  );

  Future<bool> continueWithGoogle() =>
      _run(() => ref.read(authServiceProvider).signInWithGoogle());

  Future<bool> continueAnonymously() =>
      _run(() => ref.read(authServiceProvider).signInAnonymously());

  Future<bool> sendPasswordReset(String email) =>
      _run(() => ref.read(authServiceProvider).sendPasswordReset(email));

  Future<void> signOut() async {
    _failure = null;
    await ref.read(authServiceProvider).signOut();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _failure = null;
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } on AuthException catch (e) {
      _failure = e.failure;
      state = const AsyncData(null);
      return false;
    } on Object {
      _failure = AuthFailure.unknown;
      state = const AsyncData(null);
      return false;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
