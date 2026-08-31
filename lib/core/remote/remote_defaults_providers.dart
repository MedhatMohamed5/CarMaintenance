import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dealers/data/datasources/bundled_workshops.dart';
import '../../features/dealers/domain/entities/dealer.dart';
import '../../features/fuel/domain/entities/fuel_price_defaults.dart';
import 'remote_config_service.dart';
import 'remote_defaults.dart';

/// The admin-defined values, activated copy first and network second.
///
/// **Synchronous state, not an `AsyncValue`.** Every consumer needs an answer
/// on the first frame — a fuel form pre-fills as it opens, the directory paints
/// as the tab appears — and "loading" is not an answer either can render.
/// Remote Config serves its last activated values synchronously, so this starts
/// there and swaps in a fetched set only if one arrives.
class RemoteDefaultsNotifier extends Notifier<RemoteDefaults> {
  @override
  RemoteDefaults build() {
    // One fetch per launch. These values change on the timescale of a
    // government price decision; polling them would be noise.
    Future(refresh);
    return RemoteConfigService.read();
  }

  /// **Re-reads whatever the fetch left behind, without consulting its return
  /// value.**
  ///
  /// This used to assign only when `fetchAndActivate` answered true, which
  /// looked like an optimisation and was a bug: that method reports whether
  /// *it* activated something, and it answers false whenever `init` activated
  /// the same template moments earlier — so a genuinely new set of values could
  /// be live in Remote Config and never reach this provider.
  ///
  /// Reading is a local, synchronous lookup, and [RemoteDefaults] is an
  /// `Equatable`, so an unchanged set assigns an equal value and notifies
  /// nobody. There is nothing left to optimise away.
  Future<void> refresh() async {
    await RemoteConfigService.refresh();
    // Resolved whatever the outcome: offline, throttled, or genuinely empty,
    // the app has now asked, and an empty answer is the real answer.
    state = RemoteConfigService.read().resolved();
  }
}

final remoteDefaultsProvider =
    NotifierProvider<RemoteDefaultsNotifier, RemoteDefaults>(
      RemoteDefaultsNotifier.new,
    );

/// Admin-defined pump rates. Whatever the driver has set for themselves sits
/// over these, grade by grade — see `defaultFuelPricesProvider`.
final remoteFuelPricesProvider = Provider<FuelPriceDefaults>(
  (ref) => ref.watch(remoteDefaultsProvider).fuelPrices,
);

/// The standard directory, admin-defined and read-only.
///
/// Never written to the driver's store. The list on screen is this plus their
/// own additions, merged at read time — see `dealersProvider`.
///
/// **The bundled copy is held back until the answer is known.** It used to be
/// registered as Remote Config's in-app default, which meant it appeared on
/// every cold start and was then visibly replaced the moment the published list
/// arrived. It is a fallback for *"nothing is published"*, not a placeholder
/// for *"we have not asked yet"* — so it waits for [RemoteDefaults.isResolved].
final standardWorkshopsProvider = Provider<List<Dealer>>((ref) {
  final defaults = ref.watch(remoteDefaultsProvider);
  if (defaults.workshops.isNotEmpty) return defaults.workshops;
  return defaults.isResolved ? BundledWorkshops.all() : const [];
});

/// The authorised network's support number, or null while the app does not yet
/// know whether one is published.
///
/// Named for what it resolves to rather than where it came from — like
/// [standardWorkshopsProvider], and unlike [remoteFuelPricesProvider], which
/// really is the published layer alone with the driver's own sitting over it.
///
/// **Null rather than the compiled-in number, for the same reason the directory
/// waits.** Showing the bundled figure and swapping it a second later is the
/// behaviour this whole layer exists to remove, and a phone number is a worse
/// thing to show wrongly than a list — somebody may already be dialling it.
final supportHotlineProvider = Provider<String?>((ref) {
  final defaults = ref.watch(remoteDefaultsProvider);
  final published = defaults.hotline;
  if (published != null) return published;
  return defaults.isResolved ? BundledWorkshops.ezzElarabHotline : null;
});

/// True while the app still does not know whether a directory is published.
///
/// Only ever true on the very first launch after install: Remote Config keeps
/// its activated values on disk, so every later start reads them synchronously
/// and answers immediately.
final standardWorkshopsPendingProvider = Provider<bool>((ref) {
  final defaults = ref.watch(remoteDefaultsProvider);
  return defaults.workshops.isEmpty && !defaults.isResolved;
});
