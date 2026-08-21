import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Subscribes to [stream] and pushes emissions into [assign] without ever
/// mutating provider state during `build()`.
///
/// Riverpod asserts `_previousDependencies == null` ("`_performBuild` was
/// called twice") if a provider is rebuilt while it is still building, which
/// is exactly what happens when a repository stream emits synchronously from
/// inside `build()`. Deferring every assignment to a microtask guarantees the
/// current build has completed first.
StreamSubscription<T> bindStream<T>({
  required Ref ref,
  required Stream<T> stream,
  required void Function(T value) assign,
}) {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  final subscription = stream.listen((value) {
    if (disposed) return;
    Future.microtask(() {
      if (disposed) return;
      assign(value);
    });
  }, onError: (_) {});

  ref.onDispose(subscription.cancel);
  return subscription;
}
