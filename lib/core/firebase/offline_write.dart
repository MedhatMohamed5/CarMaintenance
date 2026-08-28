import 'dart:async';

import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Completes as soon as Firestore has the write, not when the server does.
///
/// **This is the difference between a form that closes and one that hangs.**
/// A Firestore write returns a `Future` that only completes once the server
/// acknowledges it. Offline, that acknowledgement never arrives — the SDK
/// applies the change to its local cache immediately, fires its listeners, and
/// keeps the future pending until the connection returns. Any UI that awaited
/// it sat on a spinner forever while the data it was waiting for was already
/// on screen behind the dialog. Closing the sheet by hand revealed the entry
/// saved perfectly.
///
/// Firestore's own guidance is not to await these for UI purposes: the write is
/// durable the moment it is accepted, queued on disk, and replayed on
/// reconnect. What is dropped here is the *confirmation*, not the write.
///
/// The error handler is the reason this is a function rather than a bare
/// `unawaited`. An un-awaited future that throws — a permission denied, a
/// malformed document — would surface as an unhandled asynchronous error and
/// take the zone down with it. Failures are swallowed rather than shown,
/// because by then the user has moved on and there is no dialog left to tell.
///
/// Swallowed, but no longer silent: each one is filed as a non-fatal, which
/// makes this the single most useful crash-reporting hook in the app. A write
/// that never lands is invisible from the driver's side — the entry is right
/// there in the local cache — and surfaces weeks later as "my other phone is
/// missing something". Without a report there is nothing at all to go on.
Future<void> fireAndForget(Future<void> write, {String? label}) {
  unawaited(
    write.catchError((Object error, StackTrace stack) {
      debugPrint(
        'Firestore write failed${label == null ? '' : ' ($label)'}: $error',
      );
      CrashReporter.recordError(
        error,
        stack,
        reason: 'firestore write failed${label == null ? '' : ' ($label)'}',
      );
    }),
  );
  return Future<void>.value();
}
