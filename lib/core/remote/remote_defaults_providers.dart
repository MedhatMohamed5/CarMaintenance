import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dealers/data/datasources/dealer_seed_data.dart';
import '../../features/dealers/domain/entities/dealer.dart';
import '../../features/fuel/domain/entities/fuel_price_defaults.dart';
import '../firebase/firebase_bootstrap.dart';
import '../firebase/firebase_config.dart';
import '../providers/app_providers.dart';
import 'remote_defaults.dart';
import 'remote_defaults_repository.dart';

final remoteDefaultsRepositoryProvider = Provider<RemoteDefaultsRepository>(
  (ref) => RemoteDefaultsRepository(
    preferences: ref.watch(preferencesStoreProvider),
    // Null on a platform the project was never configured for, which makes the
    // repository cache-only rather than a source of exceptions.
    firestore: FirebaseConfig.isSupportedPlatform
        ? FirebaseBootstrap.firestoreOrNull
        : null,
  ),
);

/// The published defaults, cache first and network second.
///
/// **Synchronous state, not an `AsyncValue`.** Every consumer needs an answer
/// on the first frame — a fuel form pre-fills as it opens, the directory paints
/// as the tab appears — and "loading" is not an answer either can render. The
/// cached copy is available synchronously, so this starts there and swaps in a
/// fetched set only if one arrives.
class RemoteDefaultsNotifier extends Notifier<RemoteDefaults> {
  @override
  RemoteDefaults build() {
    final repository = ref.read(remoteDefaultsRepositoryProvider);
    // One fetch per app launch. This document changes on the timescale of a
    // government fuel-price decision; polling it would be noise.
    Future(refresh);
    return repository.cached();
  }

  Future<void> refresh() async {
    final fetched = await ref.read(remoteDefaultsRepositoryProvider).fetch();
    // Null means "nothing new" — offline, unconfigured, or an empty document.
    // Holding the cached copy is the correct response to all three.
    if (fetched == null) return;
    state = fetched;
  }
}

final remoteDefaultsProvider =
    NotifierProvider<RemoteDefaultsNotifier, RemoteDefaults>(
      RemoteDefaultsNotifier.new,
    );

/// Published pump prices, under whatever the driver has set for themselves.
final remoteFuelPricesProvider = Provider<FuelPriceDefaults>(
  (ref) => ref.watch(remoteDefaultsProvider).fuelPrices,
);

/// The directory as published, falling back to the copy compiled into the app.
///
/// The bundled seed is not dead weight: it is what a first launch shows before
/// any fetch has completed, what an offline install shows forever, and what a
/// build running without Firebase shows at all.
final remoteWorkshopsProvider = Provider<List<Dealer>>((ref) {
  final published = ref.watch(remoteDefaultsProvider).workshops;
  return published.isEmpty ? DealerSeedData.all() : published;
});
