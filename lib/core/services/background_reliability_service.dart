import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase/crash_reporter.dart';
import '../localization/app_localizations.dart';
import '../platform/platform_capabilities.dart';
import '../widgets/common_widgets.dart';

/// Surfaces the switches that decide whether a scheduled reminder actually
/// fires once the app is no longer in the foreground.
///
/// `flutter_local_notifications` hands every reminder to the OS's own
/// `AlarmManager`, which is meant to fire regardless of whether the app is
/// running. On stock Android that holds. On Xiaomi (MIUI), Oppo (ColorOS),
/// Vivo (FuntouchOS) and OnePlus, it does not: an app the OEM's battery
/// manager has not whitelisted has its alarms silently dropped the moment it
/// leaves the foreground, and a fresh install additionally needs its
/// "autostart" toggle turned on before the OS will run it in the background
/// at all. Neither switch has a standard Android API — both are opened
/// through manufacturer-specific screens.
///
/// **Our own code, not a package.** This used `disable_battery_optimization`,
/// whose build script still called `jcenter()` — gone in Gradle 9 — and whose
/// dialogs pulled in a pre-AndroidX library that kept Jetifier on. The screens
/// it opened now live in `MainActivity` as a list tried in order, and the
/// explanations are the app's own dialogs, styled and translated like every
/// other.
///
/// Every step is defensive: the manufacturer screens are undocumented
/// surfaces that can be missing or renamed on a given firmware build, so a
/// failure here must never take the settings screen down with it. Landing on
/// the *exact* screen is not something any app can promise — two different
/// manufacturers tested each fell back to a plainer battery page — which is
/// why the dialogs carry the instructions for whatever screen the driver
/// actually lands on. Android's own battery-optimisation request is the one
/// documented API here, and the one part guaranteed to work.
class BackgroundReliabilityService {
  const BackgroundReliabilityService._();

  static const MethodChannel _channel = MethodChannel(
    'vehicle_care/background',
  );

  /// How long a step waits for the driver to come back from a settings
  /// screen before carrying on regardless.
  static const Duration _returnTimeout = Duration(minutes: 10);

  /// Walks the driver through each switch this device has, one at a time:
  /// the manufacturer's autostart screen, then its battery-saver allowlist,
  /// then Android's own "ignore battery optimisations" prompt. A screen this
  /// device does not have is skipped, and so is the prompt once granted.
  ///
  /// **One screen at a time.** Each manufacturer screen is opened only after
  /// its explanation is accepted, and the next step waits until the driver is
  /// back in the app — opened back to back, the later screens would stack on
  /// top of the first and be seen in reverse.
  static Future<void> requestReliableBackgroundDelivery(
    BuildContext context,
  ) async {
    if (!AppPlatform.supportsBackgroundReliabilitySettings) return;
    final l10n = context.l10n;
    try {
      if (await _ask('hasAutoStart') && context.mounted) {
        final go = await confirmAction(
          context,
          title: l10n.raw('notifAutoStartDialogTitle'),
          message: l10n.raw('notifAutoStartDialogBody'),
          confirmLabel: l10n.raw('openSettings'),
          icon: Icons.restart_alt_rounded,
          destructive: false,
        );
        if (go && await _ask('openAutoStart')) await _backInApp();
      }

      if (!context.mounted) return;
      if (await _ask('hasPowerSaving') && context.mounted) {
        final go = await confirmAction(
          context,
          title: l10n.raw('notifBatteryDialogTitle'),
          message: l10n.raw('notifBatteryDialogBody'),
          confirmLabel: l10n.raw('openSettings'),
          icon: Icons.battery_saver_outlined,
          destructive: false,
        );
        if (go && await _ask('openPowerSaving')) await _backInApp();
      }

      if (!await _ask('isIgnoringBatteryOptimizations')) {
        await _ask('requestIgnoreBatteryOptimizations');
      }
    } on Object catch (error, stack) {
      debugPrint('Background reliability settings unavailable: $error');
      CrashReporter.recordError(
        error,
        stack,
        reason: 'background reliability settings unavailable',
      );
    }
  }

  static Future<bool> _ask(String method) async =>
      await _channel.invokeMethod<bool>(method) ?? false;

  /// Completes when the app is resumed — the driver is back from the screen
  /// just opened — or after [_returnTimeout], whichever comes first.
  static Future<void> _backInApp() {
    final back = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!back.isCompleted) back.complete();
      },
    );
    return back.future
        .timeout(_returnTimeout, onTimeout: () {})
        .whenComplete(listener.dispose);
  }
}
