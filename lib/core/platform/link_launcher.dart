import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/crash_reporter.dart';
import 'platform_capabilities.dart';

abstract interface class LinkLauncher {
  Future<bool> dial(String number);

  /// Shows a point on a map. For "take me there", use [directionsTo].
  ///
  /// **Coordinates only.** This used to accept a name-and-address `query` as a
  /// fallback for rows with no pin, which was dropped when the app stopped
  /// offering navigation to a workshop it cannot actually locate — the search
  /// landed on whatever the map provider made of the string, and for a back
  /// street that is regularly the wrong governorate.
  Future<bool> openMap({required double lat, required double lng});

  Future<bool> directionsTo({required double lat, required double lng});
}

class UrlLauncherLink implements LinkLauncher {
  const UrlLauncherLink();

  @override
  Future<bool> dial(String number) {
    final sanitised = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    return _launch(
      Uri(scheme: 'tel', path: sanitised),
      mode: AppPlatform.supportsPhoneDialing
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
  }

  @override
  Future<bool> openMap({required double lat, required double lng}) => _launch(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
  );

  @override
  Future<bool> directionsTo({required double lat, required double lng}) =>
      _launch(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ),
      );

  Future<bool> _launch(Uri uri, {LaunchMode? mode}) async {
    try {
      return await launchUrl(
        uri,
        mode:
            mode ??
            (AppPlatform.prefersInAppBrowser
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication),
        webOnlyWindowName: AppPlatform.isWeb ? '_blank' : null,
      );
    } catch (error, stack) {
      debugPrint('Launch failed for $uri: $error');
      CrashReporter.recordError(
        error,
        stack,
        reason: 'launch failed: ${uri.scheme}',
      );
      return false;
    }
  }
}
