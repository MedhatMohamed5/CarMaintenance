import 'dart:async';
import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Routes uncaught errors to Crashlytics, and stays silent when it cannot.
///
/// Three separate error channels have to be captured, because Flutter does not
/// funnel them together:
///
/// * `FlutterError.onError` — anything thrown inside the framework: build,
///   layout, paint, gesture callbacks.
/// * `PlatformDispatcher.instance.onError` — asynchronous errors that escape
///   the zone, which is where an un-awaited `Future` ends up.
/// * `Isolate.current.addErrorListener` — errors from background isolates,
///   which the other two never see at all. The PDF export runs work off the
///   main isolate, so this is not hypothetical here.
///
/// **Availability is checked at call time, not at install time.** The handlers
/// are installed in `main()` before Firebase has initialised — that ordering is
/// deliberate, since a crash during bootstrap is exactly the kind worth having
/// — so every path has to tolerate Crashlytics not being there yet, and on
/// desktop never being there at all.
class CrashReporter {
  const CrashReporter._();

  static bool get _live => FirebaseBootstrap.isAvailable;

  /// Installs the handlers. Safe to call before Firebase exists.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      if (_live) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, reason: 'uncaught async error');
      // Returning true marks the error handled; without it the platform
      // reports it a second time through its own channel.
      return true;
    };

    // dart:isolate has no web implementation; Isolate.current throws
    // Unsupported operation there, which would crash before runApp.
    if (!kIsWeb) {
      Isolate.current.addErrorListener(
        RawReceivePort((dynamic pair) {
          final parts = pair as List<dynamic>;
          recordError(
            parts.first,
            parts.last == null
                ? null
                : StackTrace.fromString('${parts.last}'),
            reason: 'isolate error',
            fatal: true,
          );
        }).sendPort,
      );
    }
  }

  /// Turns collection on once Firebase is up.
  ///
  /// Debug runs are excluded on purpose: a dashboard full of crashes from a
  /// laptop mid-edit is a dashboard nobody reads, and it hides the one real
  /// report from a real driver.
  static Future<void> enable() async {
    if (!_live) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  /// Tags reports with the signed-in uid so one driver's repeated crash reads
  /// as one problem rather than several. Pass null on sign-out.
  static Future<void> setUser(String? uid) async {
    if (!_live) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
  }

  /// Records a caught error that the app recovered from.
  ///
  /// The interesting ones are the failures the app deliberately swallows — a
  /// queued Firestore write that never lands, an export that fails to open.
  /// Those produce a support ticket that says only "it didn't work", and this
  /// is what turns that into a stack trace.
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_live) {
      debugPrint(
        'Unreported error${reason == null ? '' : ' ($reason)'}: $error',
      );
      return;
    }
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      ),
    );
  }

  /// Breadcrumb attached to whatever crash comes next.
  static void log(String message) {
    if (!_live) return;
    unawaited(FirebaseCrashlytics.instance.log(message));
  }
}
