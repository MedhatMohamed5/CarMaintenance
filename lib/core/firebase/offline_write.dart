import 'dart:async';

import 'package:flutter/foundation.dart';

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
/// take the zone down with it. Failures are logged and swallowed, because by
/// then the user has moved on and there is no dialog left to tell.
Future<void> fireAndForget(Future<void> write, {String? label}) {
  unawaited(
    write.catchError((Object error, StackTrace stack) {
      debugPrint(
        'Firestore write failed${label == null ? '' : ' ($label)'}: $error',
      );
    }),
  );
  return Future<void>.value();
}
