import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/foundation.dart';

import '../firebase/crash_reporter.dart';

/// Surfaces the two OEM-level switches that decide whether a scheduled
/// reminder actually fires once the app is no longer in the foreground.
///
/// `flutter_local_notifications` hands every reminder to the OS's own
/// `AlarmManager`, which is meant to fire regardless of whether the app is
/// running. On stock Android that holds. On Xiaomi (MIUI), Oppo (ColorOS),
/// Vivo (FuntouchOS) and OnePlus, it does not: an app the OEM's battery
/// manager has not whitelisted has its alarms silently dropped the moment it
/// leaves the foreground, and a fresh install additionally needs its
/// "autostart" toggle turned on before the OS will run it in the background
/// at all. Neither switch has a standard Android API — both are opened
/// through manufacturer-specific settings screens, which is what this plugin
/// wraps.
///
/// Every call is defensive: the underlying screens are undocumented OEM
/// surfaces that can be missing or renamed on a given firmware build, so a
/// failure here must never take the settings screen down with it.
class BackgroundReliabilityService {
  const BackgroundReliabilityService._();

  /// Walks the driver through both switches in one flow: the manufacturer's
  /// autostart permission, then Android's own "ignore battery optimizations"
  /// prompt plus the manufacturer's battery-saver allowlist. Each dialog is
  /// skipped by the native side when it does not apply to this device or is
  /// already granted.
  static Future<void> requestReliableBackgroundDelivery({
    required String autoStartTitle,
    required String autoStartMessage,
    required String batteryTitle,
    required String batteryMessage,
  }) async {
    try {
      await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
        autoStartTitle,
        autoStartMessage,
        batteryTitle,
        batteryMessage,
      );
    } catch (error, stack) {
      debugPrint('Background reliability settings unavailable: $error');
      CrashReporter.recordError(
        error,
        stack,
        reason: 'background reliability settings unavailable',
      );
    }
  }
}
