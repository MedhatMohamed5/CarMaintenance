/// Who is signed in, as the rest of the app needs to know them.
///
/// Deliberately not Firebase's `User`. The repositories and providers only ever
/// need an id to scope data by and something to show in Settings; binding them
/// to a vendor type would put `firebase_auth` in the import graph of every
/// layer that touches a signed-in user.
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  /// The scope key for everything this user owns. Never null while signed in,
  /// which is what makes cross-device hydration possible: the same id on a
  /// second device reaches the same data.
  final String id;

  final String? email;
  final String? displayName;

  /// Signed in without an account. Their data lives in the cloud and survives a
  /// reinstall only if they later attach an email — worth telling them before
  /// they rely on it.
  final bool isAnonymous;

  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : (email ?? id);
}

/// Why a sign-in attempt did not produce a user.
///
/// Named causes rather than raw exception strings, for the same reason
/// `LocationFailure` is: each one needs a different sentence, and a Firebase
/// error code is not something a driver can act on.
enum AuthFailure {
  /// The build has placeholder Firebase credentials, or initialisation failed.
  /// Nothing the user does will help; the app stays local-only.
  notConfigured,

  invalidEmail,
  wrongPassword,
  userNotFound,
  emailInUse,
  weakPassword,

  /// Offline, or the project is unreachable.
  network,

  /// The user backed out of the Google sheet. Not an error — nothing should be
  /// shown for it, which is why it is named rather than folded into [unknown].
  cancelled,

  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException($failure)';
}

/// Sign-in, sign-up and sign-out.
///
/// An interface so the app can run — and be reasoned about — with no Firebase
/// project at all. [LocalAuthService] stands in when Firebase is unconfigured,
/// which is the state this repository ships in today.
abstract interface class AuthService {
  /// Emits on every change of signed-in state, including the first resolution
  /// at startup. Null means signed out.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Google, which most drivers already have on the phone.
  ///
  /// Preferred over email for the obvious reason: no password to invent and
  /// none to forget, and the account already exists.
  Future<AppUser> signInWithGoogle();

  /// A user with no credentials, so the app can sync before anyone commits to
  /// an account. Upgrading later keeps the same id, and therefore the same data.
  Future<AppUser> signInAnonymously();

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);
}
