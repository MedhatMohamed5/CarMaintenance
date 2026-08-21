import 'package:flutter/foundation.dart';

class AppPlatform {
  const AppPlatform._();

  static bool get isWeb => kIsWeb;

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

  static bool get supportsFileSystem => !kIsWeb;

  static bool get supportsPhoneDialing => isMobile;

  static bool get prefersInAppBrowser => kIsWeb;
}
