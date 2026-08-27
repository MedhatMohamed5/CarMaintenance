import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// The app's own view of whether Firebase can be used here.
///
/// **Kept out of `firebase_options.dart` on purpose.** That file is generated
/// by `flutterfire configure` and rewritten in full every time it runs, so
/// anything written into it is lost the next time someone adds a platform.
/// This wrapper is where the app's questions about Firebase live.
///
/// [optionsOrNull] exists because the generated file *throws* for any platform
/// that was not configured — Windows, macOS and Linux in this project. That is
/// reasonable for a file meant to be read on a supported target, and wrong as
/// a control-flow signal: the app runs on Windows during development, and
/// "Firebase is not set up for this platform" is a normal state, not an error.
class FirebaseConfig {
  const FirebaseConfig._();

  /// The options for this platform, or null where none were generated.
  static FirebaseOptions? get optionsOrNull {
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } on UnsupportedError {
      // Desktop, unless someone reruns `flutterfire configure` and adds it.
      return null;
    }
  }

  /// Whether this build has credentials for the platform it is running on.
  ///
  /// Says nothing about whether initialisation succeeded or the network is up
  /// — see `cloudAvailableProvider` for the question the UI actually asks.
  static bool get isSupportedPlatform => optionsOrNull != null;

  static String? get projectId => optionsOrNull?.projectId;
}
