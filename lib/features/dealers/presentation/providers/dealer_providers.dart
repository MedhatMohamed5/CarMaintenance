import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/remote/remote_defaults_providers.dart';
import '../../data/repositories/dealer_repository_impl.dart';
import '../../data/repositories/firestore_workshop_overrides.dart';
import '../../domain/entities/dealer.dart';
import '../../domain/repositories/dealer_repository.dart';

final dealerRepositoryProvider = Provider<DealerRepository>(
  (ref) => DealerRepositoryImpl(),
);

/// The account's copy of the driver's own workshops, or null when signed out.
///
/// Null is the signed-out case and every caller treats it as "local only" —
/// which is correct, not degraded: without an account there is no tree to sync
/// to, and the local store already holds everything.
final workshopOverridesProvider = Provider<FirestoreWorkshopOverrides?>((ref) {
  if (!ref.watch(isRemoteBackendProvider)) return null;
  return FirestoreWorkshopOverrides(ref.watch(firestorePathsProvider));
});

final authorizedHotlineProvider = Provider<String>(
  (ref) => ref.watch(dealerRepositoryProvider).authorizedHotline,
);

/// The directory the screens read: published rows underneath, the driver's own
/// on top.
///
/// Both layers arrive asynchronously and neither blocks the first frame. The
/// local store is complete and readable the moment the app starts — the
/// bootstrap seeded it from the bundled copy — and the two listeners below
/// replace parts of it as the network answers.
class DealersNotifier extends Notifier<List<Dealer>> {
  @override
  List<Dealer> build() {
    // **Listeners, not `watch`.** Both of these are writes, and a write during
    // a provider build re-enters the graph. Same rule `reminderSignatureProvider`
    // follows for the same reason.
    ref.listen<List<Dealer>>(remoteWorkshopsProvider, (previous, next) {
      if (previous != next) applyDefaults(next);
    }, fireImmediately: true);

    ref.listen<FirestoreWorkshopOverrides?>(workshopOverridesProvider, (
      previous,
      next,
    ) {
      if (next != null) _pullOverrides(next);
    }, fireImmediately: true);

    return ref.read(dealerRepositoryProvider).getAll();
  }

  void _refresh() => state = ref.read(dealerRepositoryProvider).getAll();

  /// Applies a freshly published directory over the rows it owns.
  Future<void> applyDefaults(List<Dealer> defaults) async {
    await ref.read(dealerRepositoryProvider).syncDefaults(defaults);
    _refresh();
  }

  /// Brings this account's own workshops down onto a device that has not seen
  /// them — a second phone, or a reinstall.
  ///
  /// A one-way pull, and deliberately so. Rows only ever arrive here; nothing
  /// deletes a local row because the account does not list it, because that is
  /// indistinguishable from a row added offline that has not been pushed yet,
  /// and the wrong guess loses the driver's data.
  Future<void> _pullOverrides(FirestoreWorkshopOverrides overrides) async {
    final remote = await overrides.fetchAll();
    if (remote.isEmpty) return;
    final repository = ref.read(dealerRepositoryProvider);
    for (final dealer in remote) {
      await repository.upsert(dealer);
    }
    _refresh();
  }

  /// Saves a row, and pushes it to the account when it is one the driver owns.
  ///
  /// The ownership test is what keeps forty published rows out of the account:
  /// only something added or edited here is worth carrying to another device.
  Future<void> upsert(Dealer dealer) async {
    await ref.read(dealerRepositoryProvider).upsert(dealer);
    if (dealer.isUserOwned) {
      await ref.read(workshopOverridesProvider)?.put(dealer);
    }
    _refresh();
  }

  /// Ratings stay on the device that gave them — the app is a directory, not a
  /// review platform — so this writes locally and nowhere else.
  Future<void> rate(String id, double rating) async {
    await ref.read(dealerRepositoryProvider).rate(id, rating);
    _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(dealerRepositoryProvider).delete(id);
    await ref.read(workshopOverridesProvider)?.delete(id);
    _refresh();
  }
}

final dealersProvider = NotifierProvider<DealersNotifier, List<Dealer>>(
  DealersNotifier.new,
);

final dealerQueryProvider = StateProvider<String>((ref) => '');

final dealerKindFilterProvider = StateProvider<DealerKind?>((ref) => null);

final filteredDealersProvider = Provider<List<Dealer>>((ref) {
  final all = ref.watch(dealersProvider);
  final query = ref.watch(dealerQueryProvider).trim().toLowerCase();
  final kind = ref.watch(dealerKindFilterProvider);

  return all
      .where((d) {
        if (kind != null && d.kind != kind) return false;
        if (query.isEmpty) return true;
        return [
          d.name,
          d.brand,
          d.city,
          d.address,
          d.phone,
          d.altPhone,
          d.hotline,
        ].whereType<String>().any((f) => f.toLowerCase().contains(query));
      })
      .toList(growable: false);
});

final dealerCitiesProvider = Provider<List<String>>((ref) {
  final cities = ref
      .watch(dealersProvider)
      .map((d) => d.city)
      .where((c) => c.isNotEmpty)
      .toSet();
  return cities.toList()..sort();
});

class DealerController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> add({
    required String name,
    required String city,
    required DealerKind kind,
    String? brand,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
    String? openingHours,
    String? notes,
  }) => _run(
    () => ref
        .read(dealersProvider.notifier)
        .upsert(
          Dealer(
            id: ref.read(uuidProvider).v4(),
            name: name.trim(),
            city: city.trim(),
            kind: kind,
            brand: brand?.trim(),
            address: address?.trim(),
            phone: phone?.trim(),
            latitude: latitude,
            longitude: longitude,
            openingHours: openingHours?.trim(),
            notes: notes?.trim(),
            isUserAdded: true,
          ),
        ),
  );

  /// Saves an edit, and records that the driver made it.
  ///
  /// **[Dealer.isUserEdited] is set here rather than at the call site**, so
  /// there is no way to save a change through the app that the next published
  /// refresh would then overwrite. A row they added is already theirs and keeps
  /// the flag it has.
  Future<bool> save(Dealer dealer) => _run(
    () => ref
        .read(dealersProvider.notifier)
        .upsert(
          dealer.isUserAdded ? dealer : dealer.copyWith(isUserEdited: true),
        ),
  );

  /// Puts an edited published row back the way it was published.
  ///
  /// Deleting it is not the same thing and would be wrong: the row belongs to
  /// the directory, and a driver who wants their correction gone wants the
  /// original back, not a gap. Clearing the flag hands it to the next refresh,
  /// which rewrites it from the published copy.
  Future<bool> resetToPublished(Dealer dealer) async {
    if (!dealer.isUserEdited || dealer.isUserAdded) return false;
    final ok = await _run(
      () => ref
          .read(dealersProvider.notifier)
          .upsert(dealer.copyWith(isUserEdited: false)),
    );
    if (!ok) return false;
    await ref.read(workshopOverridesProvider)?.delete(dealer.id);
    await ref
        .read(dealersProvider.notifier)
        .applyDefaults(ref.read(remoteWorkshopsProvider));
    return true;
  }

  Future<bool> rate(String id, double rating) =>
      _run(() => ref.read(dealersProvider.notifier).rate(id, rating));

  Future<bool> remove(String id) =>
      _run(() => ref.read(dealersProvider.notifier).remove(id));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final dealerControllerProvider = AsyncNotifierProvider<DealerController, void>(
  DealerController.new,
);
