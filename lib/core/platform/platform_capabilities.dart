import 'package:flutter/foundation.dart';

class AppPlatform {
  const AppPlatform._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get supportsLocalNotifications => isMobile;

  /// Android-only: iOS notifications keep firing while the app is closed
  /// without any user action, so there is nothing to surface there.
  static bool get supportsBackgroundReliabilitySettings => isAndroid;

  static bool get supportsFileSystem => !kIsWeb;

  static bool get supportsPhoneDialing => isMobile;

  static bool get prefersInAppBrowser => kIsWeb;
}
