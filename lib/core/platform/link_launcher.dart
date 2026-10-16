import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/crash_reporter.dart';
import '../utils/latin_digits.dart';
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
  ///
  /// On Android both this and [directionsTo] let the driver pick the app —
  /// Google Maps, Waze, Uber — rather than always opening Google Maps.
  /// [label] names the pin in whichever app opens it.
  Future<bool> openMap({
    required double lat,
    required double lng,
    String? label,
  });

  Future<bool> directionsTo({
    required double lat,
    required double lng,
    String? label,
  });

  /// Opens a web link the driver wrote down — in a note, say.
  Future<bool> openUrl(Uri uri);
}

class UrlLauncherLink implements LinkLauncher {
  const UrlLauncherLink();

  @override
  Future<bool> dial(String number) {
    // Latin first: a number saved with Arabic digits — typed before the
    // fields converted them, or published that way — would otherwise lose
    // every digit to the filter below and dial nothing.
    final sanitised = toLatinDigits(
      number,
    ).replaceAll(RegExp(r'[^0-9+*#]'), '');
    return _launch(
      Uri(scheme: 'tel', path: sanitised),
      mode: AppPlatform.supportsPhoneDialing
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
  }

  @override
  Future<bool> openMap({
    required double lat,
    required double lng,
    String? label,
  }) async =>
      await _openGeo(lat, lng, label) ||
      await _launch(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      );

  /// A route preview on the web. On Android it goes through the same app
  /// choice as [openMap]: there is no intent every navigation app answers
  /// for a route, and each one offers directions from the pin it opens.
  @override
  Future<bool> directionsTo({
    required double lat,
    required double lng,
    String? label,
  }) async =>
      await _openGeo(lat, lng, label) ||
      await _launch(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ),
      );

  /// A `geo:` link, which Android hands to every installed map and ride app
  /// and asks the driver to choose — the way a location shared in WhatsApp
  /// opens. A google.com/maps link goes straight to Google Maps instead,
  /// because that app claims the domain. False off Android, or when no app on
  /// the device takes it, so the caller falls back to the web link.
  Future<bool> _openGeo(double lat, double lng, String? label) async {
    if (!AppPlatform.isAndroid) return false;
    final name = label?.trim() ?? '';
    final query = name.isEmpty
        ? '$lat,$lng'
        : '$lat,$lng(${Uri.encodeComponent(name)})';
    try {
      return await launchUrl(
        Uri.parse('geo:0,0?q=$query'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openUrl(Uri uri) => _launch(uri);

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
