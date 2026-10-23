import 'package:flutter/services.dart' show appFlavor;

/// Set by `--flavor`, so there is no separate entry point or dart-define.
class AppFlavor {
  const AppFlavor._();

  static const String devName = 'dev';

  /// The dev build never talks to Firebase: local data only.
  static bool get isDev => appFlavor == devName;
}
