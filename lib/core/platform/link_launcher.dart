import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/crash_reporter.dart';
import 'platform_capabilities.dart';

abstract interface class LinkLauncher {
  Future<bool> dial(String number);

  Future<bool> openMap({double? lat, double? lng, String? query});

  Future<bool> directionsTo({required double lat, required double lng});

  Future<bool> openUrl(String url);
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
  Future<bool> openMap({double? lat, double? lng, String? query}) {
    final uri = (lat != null && lng != null)
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': query ?? '',
          });
    return _launch(uri);
  }

  @override
  Future<bool> directionsTo({required double lat, required double lng}) =>
      _launch(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ),
      );

  @override
  Future<bool> openUrl(String url) => _launch(Uri.parse(url));

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
