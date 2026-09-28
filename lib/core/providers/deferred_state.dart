import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/crash_reporter.dart';

/// Subscribes to [stream] and pushes emissions into [assign] without ever
/// mutating provider state during `build()`.
///
/// Riverpod asserts `_previousDependencies == null` ("`_performBuild` was
/// called twice") if a provider is rebuilt while it is still building, which
/// is exactly what happens when a repository stream emits synchronously from
/// inside `build()`. Deferring every assignment to a microtask guarantees the
/// current build has completed first.
///
/// [source] names the data being synced — `vehicles`, `fuel-logs` — and is
/// what a failure report is filed under. It is required so that a new binding
/// cannot be added without saying what it is.
StreamSubscription<T> bindStream<T>({
  required Ref ref,
  required Stream<T> stream,
  required void Function(T value) assign,
  required String source,
}) {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  final subscription = stream.listen(
    (value) {
      if (disposed) return;
      Future.microtask(() {
        if (disposed) return;
        assign(value);
      });
    },
    // **Reported, not swallowed — and the state is deliberately left alone.**
    //
    // This used to be `onError: (_) {}`, which made a sync failure the one
    // class of error in the app that could reach nobody: a rules change that
    // started denying reads, an index that was never deployed, a quota hit —
    // all of it vanished here, on every device, with no trace.
    //
    // The notifier keeps the value it already holds rather than going to an
    // error state. That value is the last snapshot this device received —
    // Firestore's own on-disk cache included — so what is on screen is still
    // the driver's data, just no longer live. Replacing it with an error
    // because the *stream* failed would take away data they already have over
    // a problem on our side.
    //
    // Worth knowing when reading these reports: a Firestore snapshot listener
    // is finished after it errors — nothing further arrives on this stream
    // until the provider rebuilds and binds a new one. So the report marks the
    // moment this device stopped receiving updates for [source], not a blip.
    onError: (Object error, StackTrace stack) {
      if (disposed) return;
      // Deferred like the values, and re-checked: an error that lands in the
      // same turn as the provider being torn down — the listener dying as the
      // driver signs out — belongs to a subscription nobody is using any more.
      Future.microtask(() {
        if (disposed) return;
        final code = error is FirebaseException ? error.code : null;
        CrashReporter.recordError(
          error,
          stack,
          reason:
              'sync stream failed: $source'
              '${code == null ? '' : ' ($code)'}',
          tags: {
            'action': 'sync',
            'sync.source': source,
            'firestore.code': ?code,
          },
        );
      });
    },
  );

  ref.onDispose(subscription.cancel);
  return subscription;
}
