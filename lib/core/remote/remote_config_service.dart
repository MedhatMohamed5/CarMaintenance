import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../firebase/crash_reporter.dart';
import '../firebase/firebase_bootstrap.dart';
import 'remote_defaults.dart';

/// Reads the admin-defined values out of Firebase Remote Config.
///
/// **Remote Config rather than a Firestore document, and the difference that
/// matters is what happens when the network is not there.** Remote Config keeps
/// the last activated values on disk itself and serves them synchronously on
/// the next launch, and it falls back to in-app defaults before it has ever
/// fetched anything. That is the whole of the caching layer this used to
/// hand-roll, and it is the reason a first launch on a plane still knows what a
/// litre of 92 costs.
///
/// Nothing here throws. A failed fetch leaves the previously activated values
/// standing; a device that has never fetched falls back to the seed compiled
/// into the app. Both are normal states, not errors.
class RemoteConfigService {
  const RemoteConfigService._();

  /// Parameter names as they appear in the Firebase console. Both hold a JSON
  /// string.
  static const String fuelPricesKey = 'fuel_prices';
  static const String workshopsKey = 'workshops';

  /// How long an activated set is considered current.
  ///
  /// Twelve hours in release: these values change on the timescale of a
  /// government price decision or a branch opening, so fetching more often
  /// would spend the driver's data to learn nothing.
  ///
  /// **Zero in debug, and that is not a nicety.** Remote Config serves a
  /// throttled fetch straight from its cache without contacting the server, so
  /// with a twelve-hour window a developer changes a value in the console,
  /// restarts, and sees nothing — for twelve hours, with no error and no clue
  /// why. Every Remote Config integration hits this once; there is no reason to
  /// hit it twice.
  static Duration get minimumFetchInterval =>
      kDebugMode ? Duration.zero : const Duration(hours: 12);

  static FirebaseRemoteConfig? get _instance =>
      FirebaseBootstrap.isAvailable ? FirebaseRemoteConfig.instance : null;

  /// Registers the in-app defaults and promotes anything a previous run
  /// fetched but did not activate.
  ///
  /// Called from the bootstrap, after Firebase is up and before the first
  /// frame, so [read] has real values to return immediately. The network fetch
  /// is deliberately *not* awaited here — see [refresh].
  static Future<void> init() async {
    final config = _instance;
    if (config == null) return;

    await config.setConfigSettings(
      RemoteConfigSettings(
        // Generous: a fetch that hangs must not hold the splash.
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: minimumFetchInterval,
      ),
    );

    // **No `setDefaults`, deliberately.** Registering the bundled directory as
    // Remote Config's own default made an unpublished template and an
    // un-fetched one indistinguishable: `getString` answered with the seed in
    // both cases, so the app showed it immediately and then visibly swapped it
    // for the real list a second later. Leaving the default unset means an
    // empty string genuinely means "nothing here", and the decision about when
    // to fall back moves to `standardWorkshopsProvider`, which knows whether a
    // fetch has happened yet.
    //
    // It also stops re-encoding the whole seed to JSON on every single launch.

    // Covers exactly one case: a previous run fetched a new template and was
    // killed before it could activate it. Values activated in an earlier run
    // are already live and do not need this.
    //
    // It also means the [refresh] that follows will report `false` for that
    // template, because this call has already activated it — which is fine,
    // and is why nothing keys off that return value any more.
    await config.activate();
  }

  /// The currently active values. Synchronous, so the first frame can use them.
  ///
  /// Empty *and resolved* where Firebase is not configured: no answer is ever
  /// coming on this platform, so callers should fall back at once rather than
  /// wait for a fetch that will not happen.
  static RemoteDefaults read() {
    final config = _instance;
    if (config == null) return const RemoteDefaults(isResolved: true);

    return RemoteDefaults.parse(
      fuelPricesJson: config.getString(fuelPricesKey),
      workshopsJson: config.getString(workshopsKey),
      // **A fetch that succeeded in *any* run settles the question.** The status
      // and the activated values are both kept on disk, so a device that reached
      // the server yesterday already knows today, before this run's fetch, that
      // an empty directory is genuinely empty.
      //
      // Without this the fallback waited on every single launch of a project
      // that never publishes a `workshops` parameter — a spinner before the
      // bundled list, every time, to re-learn something already known.
    ).withResolved(config.lastFetchStatus == RemoteConfigFetchStatus.success);
  }

  /// Fetches and activates in the background.
  ///
  /// **The return value is diagnostic, not a signal to act on.**
  ///
  /// `fetchAndActivate` reports whether *it* activated something new, and it
  /// answers false for every ordinary outcome: throttled by
  /// [minimumFetchInterval], the same template returned again, no template at
  /// all, or [init] activating it moments earlier. None of those mean the
  /// values on hand are stale, so the caller re-reads unconditionally.
  static Future<bool> refresh() async {
    final config = _instance;
    if (config == null) return false;
    try {
      final activated = await config.fetchAndActivate();
      if (kDebugMode && !activated) {
        debugPrint(
          'Remote Config: nothing new activated '
          '(status ${config.lastFetchStatus.name}, '
          'last success ${config.lastFetchTime}). '
          'Values in use are the ones already on hand.',
        );
      }
      return activated;
    } catch (error, stack) {
      CrashReporter.recordError(
        error,
        stack,
        reason: 'remote config fetch failed',
      );
      return false;
    }
  }
}
