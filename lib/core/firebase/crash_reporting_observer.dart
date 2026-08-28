import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporter.dart';

/// Files every provider failure as a non-fatal.
///
/// **This is the gap the three top-level handlers cannot close.** Riverpod
/// catches a provider's error itself and parks it in the provider's state as an
/// `AsyncError`, which is the correct thing for it to do — the UI gets to
/// render a retry instead of the app dying. But it means the error is *handled*
/// by the time anything else could see it, so `FlutterError.onError` and
/// `PlatformDispatcher.onError` never fire. Without this observer a repository
/// that throws on every read, a stream that dies, a `CacheFailure` out of
/// `JsonBox` — all of it is invisible from outside the device.
///
/// [ProviderObserver.providerDidFail] turns out to cover every route a provider
/// can fail by. Measured against Riverpod 2.6.1, all five reach it:
///
/// * a sync `Provider` throwing during build
/// * a `FutureProvider` whose future throws
/// * a `StreamProvider` whose stream emits an error
/// * an `AsyncNotifier` throwing in `build()`
/// * a notifier assigning `state = AsyncError(...)` by hand
///
/// The last one is worth naming because it looks like it should arrive as an
/// ordinary value update and does not — so there is no need to also inspect
/// `didUpdateProvider` for `AsyncError`, which would have re-reported on every
/// rebuild for as long as the provider stayed errored.
class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    CrashReporter.recordError(
      error,
      stackTrace,
      reason: 'provider failed: ${_name(provider)}',
    );
  }

  /// Providers are usually anonymous, so the variable name is the only handle
  /// on which one failed. `name` is set when the author gave one; the runtime
  /// type is a weak fallback but still narrows it to a kind.
  static String _name(ProviderBase<Object?> provider) =>
      provider.name ?? provider.runtimeType.toString();
}
