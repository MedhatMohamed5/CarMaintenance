import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Routes uncaught errors to Sentry, and stays silent when it cannot.
///
/// **One seam for the whole app.** Nothing outside this file names the
/// reporting provider — that is what made replacing Crashlytics a change to one
/// file rather than to the eleven call sites spread across the codebase.
///
/// **Sentry installs its own error handlers; this does not.** `SentryFlutter.init`
/// wraps `runApp` and takes over `FlutterError.onError`,
/// `PlatformDispatcher.instance.onError` and the isolate error listener itself.
/// The previous version wired all three by hand for Crashlytics, and leaving
/// that in place alongside Sentry would report every framework error twice.
/// What remains here is the deliberate, called-by-hand reporting: a recovered
/// failure the app swallowed, a breadcrumb, the signed-in user.
class CrashReporter {
  const CrashReporter._();

  /// Where events are sent. Empty disables reporting entirely, which is what a
  /// local build gets unless it opts in.
  ///
  /// **Overridable at build time**, so a fork, a test build or a CI job can
  /// point somewhere else — or nowhere — without touching the source:
  ///
  /// ```
  /// flutter build appbundle --dart-define=SENTRY_DSN=https://…
  /// flutter build appbundle --dart-define=SENTRY_DSN=
  /// ```
  ///
  /// The default is committed on purpose. A DSN is not a credential in the
  /// sense a token is: it ships inside every copy of the app, it only permits
  /// *writing* events, and it can be rotated from the Sentry dashboard. Keeping
  /// it here is what makes a plain `flutter run` report like a real build.
  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://74f16164dab9053c5db6edb6727344fc'
        '@o4511260069527552.ingest.de.sentry.io/4512007908687952',
  );

  /// Lets a debug build report, for checking the pipeline itself. Off unless
  /// asked for; see [runGuarded].
  static const bool _reportInDebug = bool.fromEnvironment('SENTRY_IN_DEBUG');

  /// Whether events can be sent at all.
  ///
  /// **One question now, where Crashlytics needed two.** That library had no
  /// web implementation whatsoever, so this used to have to ask both "is
  /// Firebase up" and "does the reporter exist on this platform" — and the
  /// answer to the second was permanently no on web, which is where the app is
  /// developed. Sentry runs everywhere the app does, so the platform half of
  /// the question is gone.
  static bool get _live => _dsn.isNotEmpty && Sentry.isEnabled;

  /// Starts Sentry and hands control to [appRunner].
  ///
  /// The app is run *inside* Sentry's zone rather than beside it; that is what
  /// lets it catch errors thrown before the first frame, which is exactly the
  /// class of crash worth having.
  static Future<void> runGuarded(FutureOr<void> Function() appRunner) async {
    if (_dsn.isEmpty) {
      await appRunner();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = kDebugMode ? 'debug' : 'production';

      // **Errors only.** Tracing and replay bill against the same quota and
      // answer questions nobody is asking yet; turning either on later is one
      // line here.
      options.tracesSampleRate = 0;

      // The device's IP is personal data and buys nothing for a crash report.
      // The signed-in uid is attached separately by [setUser], and is the only
      // identifier this app sends.
      options.sendDefaultPii = false;

      // Debug runs are dropped rather than never collected, so the same code
      // path runs in development as in release — a reporting bug that only
      // appears in production is the worst kind to have.
      //
      // The escape hatch exists because without it the reporting itself cannot
      // be tested: every check would have to be a release build, which is the
      // slowest possible way to find out a DSN is wrong.
      //
      //   flutter run --dart-define=SENTRY_IN_DEBUG=true
      options.beforeSend = (event, hint) =>
          (kDebugMode && !_reportInDebug) ? null : event;
    }, appRunner: appRunner);
  }

  /// Tags reports with the signed-in uid so one driver's repeated crash reads
  /// as one problem rather than several. Pass null on sign-out.
  static Future<void> setUser(String? uid) async {
    if (!_live) return;
    await Sentry.configureScope(
      (scope) => scope.setUser(uid == null ? null : SentryUser(id: uid)),
    );
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
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
          if (reason != null) scope.setContexts('reason', reason);
        },
      ),
    );
  }

  /// Breadcrumb attached to whatever crash comes next.
  static void log(String message) {
    if (!_live) return;
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: message)));
  }
}
