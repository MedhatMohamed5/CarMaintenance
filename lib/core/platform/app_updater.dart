import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../firebase/crash_reporter.dart';
import '../remote/remote_config_service.dart';
import '../storage/preferences_store.dart';
import '../utils/latin_digits.dart';
import 'platform_capabilities.dart';

/// What a check left for the app to do.
enum UpdateCheckOutcome {
  /// Nothing: up to date, declined, not offered, or not available here.
  none,

  /// An optional update has finished downloading and installs on restart.
  readyToInstall,
}

/// Keeps a Play-installed build current through Google Play's in-app updates.
///
/// **Optional by default, required only when told.** An update is offered the
/// flexible way: Play asks, the download runs while the driver keeps using the
/// app, and a restart installs it. Turning it down is respected for
/// [declineCooldown] before it is offered again. A build below the
/// `min_supported_build` Remote Config value gets the immediate update
/// instead — Play's full-screen flow, for a release that must not be skipped.
///
/// Android only, and only for a build Play installed. A debug build, an APK
/// installed by hand, or a device without the Play Store makes Play answer
/// with an error, which here simply means "no update" — the normal case on
/// every development device, so it is neither shown nor reported.
class AppUpdater {
  AppUpdater(this._prefs);

  final PreferencesStore _prefs;

  /// How long an optional update stays quiet after the driver declines it.
  static const Duration declineCooldown = Duration(days: 2);

  /// One check at a time. A flexible download can take minutes, and the
  /// return to the foreground that follows it must not start a second.
  bool _busy = false;

  Future<UpdateCheckOutcome> check() async {
    if (!AppPlatform.isAndroid || _busy) return UpdateCheckOutcome.none;
    _busy = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // Downloaded on an earlier run and never installed: offer the restart
      // again rather than downloading anything.
      if (info.installStatus == InstallStatus.downloaded) {
        return UpdateCheckOutcome.readyToInstall;
      }

      // An immediate update the driver left mid-way: Play expects the app to
      // pick it back up.
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return UpdateCheckOutcome.none;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return UpdateCheckOutcome.none;
      }

      if (info.immediateUpdateAllowed && await _isBelowMinimum()) {
        // Declining a required update is not remembered: it is asked again
        // on the next launch or return to the app.
        await InAppUpdate.performImmediateUpdate();
        return UpdateCheckOutcome.none;
      }

      if (_declinedRecently) return UpdateCheckOutcome.none;
      if (!info.flexibleUpdateAllowed) {
        // Play knows of an update and allows neither flow: worth knowing why,
        // since from the outside it looks exactly like "no update".
        _report(
          StateError(
            'update available but flexible flow not allowed '
            '(code ${info.availableVersionCode}, '
            'preconditions ${info.flexibleAllowedPreconditions})',
          ),
          StackTrace.current,
        );
        return UpdateCheckOutcome.none;
      }

      // Completes once the download has finished, not when it starts.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        await _prefs.setUpdateDeclinedAt(DateTime.now());
        return UpdateCheckOutcome.none;
      }
      return result == AppUpdateResult.success
          ? UpdateCheckOutcome.readyToInstall
          : UpdateCheckOutcome.none;
    } on Object catch (error, stack) {
      if (kDebugMode) debugPrint('In-app update unavailable: $error');
      _report(error, stack);
      return UpdateCheckOutcome.none;
    } finally {
      _busy = false;
    }
  }

  /// Installs the downloaded update. Play restarts the app to do it.
  Future<void> install() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on Object catch (error) {
      if (kDebugMode) debugPrint('In-app update install failed: $error');
    }
  }

  /// Files a failed check as a warning — except the failures every build Play
  /// did not install produces, which are the normal case on a development
  /// device and would bury the ones worth reading.
  ///
  /// Play reports those two as install error -10 (the app is not owned by any
  /// account on the device: a debug build, an APK installed by hand, a
  /// pre-launch test device) and -9 (no Play Store). A third arrives with no
  /// code at all — "Failed to bind to the service" — when the Play Store app
  /// cannot be reached: missing, disabled, mid-update, or no account signed
  /// in, which is every pre-launch test device.
  ///
  /// **Matched on what Play does not translate.** The message is written in
  /// the device's language, digits included, so on an Arabic device it reads
  /// `Install Error(-١٠)` and a match on `(-10)` let every one through. The
  /// error's constant name — in the documentation link the message carries —
  /// stays in English, and so does the code at the head of the message; the
  /// digits are made Latin as well, for good measure.
  static void _report(Object error, StackTrace stack) {
    final message = toLatinDigits('$error');
    const expected = [
      'ERROR_APP_NOT_OWNED',
      'ERROR_PLAY_STORE_NOT_FOUND',
      '(-10)',
      '(-9)',
      ' -10:',
      ' -9:',
      'Failed to bind to the service',
    ];
    if (expected.any(message.contains)) return;
    CrashReporter.recordError(
      error,
      stack,
      reason: 'in-app update check failed',
      tags: {'action': 'in-app-update'},
      warning: true,
    );
  }

  bool get _declinedRecently {
    final at = _prefs.updateDeclinedAt;
    return at != null && DateTime.now().difference(at) < declineCooldown;
  }

  /// When the minimum was last fetched past Remote Config's cache.
  DateTime? _minimumFetchedAt;

  /// How often an available update may fetch the minimum afresh.
  static const Duration _minimumRefreshEvery = Duration(minutes: 30);

  /// Whether this build is below `min_supported_build`, read fresh.
  ///
  /// **Fetched past the twelve-hour cache before deciding.** Remote Config
  /// serves a release build its values at most twice a day, which suits pump
  /// prices and defeats a required update: the minimum is raised precisely
  /// because a fix cannot wait, and a device still holding yesterday's value
  /// was offered the update as optional. Only reached when Play already has
  /// an update to offer, and at most every [_minimumRefreshEvery], so it does
  /// not turn every return to the app into a fetch.
  Future<bool> _isBelowMinimum() async {
    final now = DateTime.now();
    final last = _minimumFetchedAt;
    if (last == null || now.difference(last) >= _minimumRefreshEvery) {
      _minimumFetchedAt = now;
      await RemoteConfigService.refresh(force: true);
    }
    final minimum = RemoteConfigService.minSupportedBuild();
    if (minimum <= 0) return false;
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    return build > 0 && build < minimum;
  }
}
