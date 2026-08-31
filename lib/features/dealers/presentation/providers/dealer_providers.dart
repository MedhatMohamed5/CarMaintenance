import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/remote/remote_defaults_providers.dart';
import '../../data/repositories/firestore_user_workshops.dart';
import '../../data/repositories/user_workshop_repository_impl.dart';
import '../../domain/entities/dealer.dart';
import '../../domain/entities/dealer_ratings.dart';
import '../../domain/repositories/user_workshop_repository.dart';

final userWorkshopRepositoryProvider = Provider<UserWorkshopRepository>(
  (ref) => UserWorkshopRepositoryImpl(),
);

/// The account's copy of the driver's own workshops, or null when signed out.
///
/// Null is not degraded: without an account there is no tree to sync to, and
/// the local store already holds everything they added.
final userWorkshopsStoreProvider = Provider<FirestoreUserWorkshops?>((ref) {
  if (!ref.watch(isRemoteBackendProvider)) return null;
  return FirestoreUserWorkshops(ref.watch(firestorePathsProvider));
});

// ── the driver's own workshops ─────────────────────────────────────────────

/// Workshops the driver added. Local always, and their account as well when
/// they have one.
class UserWorkshopsNotifier extends Notifier<List<Dealer>> {
  @override
  List<Dealer> build() {
    // A listener, not a `watch`: pulling is a write, and signing in is the
    // moment it has to happen.
    ref.listen<FirestoreUserWorkshops?>(userWorkshopsStoreProvider, (_, next) {
      if (next != null) _pull(next);
    }, fireImmediately: true);

    return ref.read(userWorkshopRepositoryProvider).getAll();
  }

  void _refresh() => state = ref.read(userWorkshopRepositoryProvider).getAll();

  /// Brings this account's workshops onto a device that has not seen them — a
  /// second phone, or a reinstall.
  ///
  /// One-way, and deliberately so. Rows only ever arrive here; nothing deletes
  /// a local row because the account does not list it, because that is
  /// indistinguishable from one added offline and not yet pushed, and the wrong
  /// guess loses the driver's data.
  Future<void> _pull(FirestoreUserWorkshops store) async {
    final remote = await store.fetchAll();
    if (remote.isEmpty) return;
    final repository = ref.read(userWorkshopRepositoryProvider);
    for (final workshop in remote) {
      await repository.upsert(workshop);
    }
    _refresh();
  }

  /// **Forces [Dealer.isUserAdded] rather than trusting the caller.** This
  /// notifier only ever holds rows the driver created, and the flag is what
  /// every delete and edit affordance keys off. A row that reached storage
  /// without it would be invisible to the repository and unreachable from the
  /// screen.
  Future<void> upsert(Dealer workshop) async {
    final owned = workshop.isUserAdded
        ? workshop
        : workshop.copyWith(isUserAdded: true);
    await ref.read(userWorkshopRepositoryProvider).upsert(owned);
    await ref.read(userWorkshopsStoreProvider)?.put(owned);
    _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(userWorkshopRepositoryProvider).delete(id);
    await ref.read(userWorkshopsStoreProvider)?.delete(id);
    _refresh();
  }
}

final userWorkshopsProvider =
    NotifierProvider<UserWorkshopsNotifier, List<Dealer>>(
      UserWorkshopsNotifier.new,
    );

// ── ratings ───────────────────────────────────────────────────────────────

/// Ratings given on this device, for standard and added workshops alike.
class DealerRatingsNotifier extends Notifier<DealerRatings> {
  @override
  DealerRatings build() {
    final raw = ref.read(preferencesStoreProvider).dealerRatings;
    if (raw == null || raw.isEmpty) return DealerRatings.empty;
    try {
      return DealerRatings.fromJson(jsonDecode(raw));
    } on Object {
      // A rating is a nicety; losing the map is not worth failing a launch.
      return DealerRatings.empty;
    }
  }

  Future<void> rate(String dealerId, double stars) async {
    state = state.withVote(dealerId, stars);
    await ref
        .read(preferencesStoreProvider)
        .setDealerRatings(jsonEncode(state.toJson()));
  }
}

final dealerRatingsProvider =
    NotifierProvider<DealerRatingsNotifier, DealerRatings>(
      DealerRatingsNotifier.new,
    );

// ── the merged directory ──────────────────────────────────────────────────

/// What every screen reads: the admin-defined directory **plus** the driver's
/// own workshops.
///
/// **Merged here, at read time, and stored nowhere.** The two halves have
/// different owners and different lifetimes — one is republished centrally, the
/// other belongs to an account — so materialising the merge into a single
/// store, as this used to, meant a stale copy of the published half could
/// outlive its publish, and there was no point in the code where "standard" and
/// "mine" were still distinguishable.
///
/// An id collision resolves to the driver's row. It is not expected — their ids
/// are UUIDs — but silently replacing something they created would be the worse
/// failure of the two.
final dealersProvider = Provider<List<Dealer>>((ref) {
  final standard = ref.watch(standardWorkshopsProvider);
  final own = ref.watch(userWorkshopsProvider);
  final ratings = ref.watch(dealerRatingsProvider);

  final byId = <String, Dealer>{
    for (final workshop in standard) workshop.id: workshop,
    for (final workshop in own) workshop.id: workshop,
  };

  final merged = [
    for (final workshop in byId.values)
      switch (ratings.ratingOf(workshop.id)) {
        null => workshop,
        final rating => workshop.copyWith(
          rating: rating.rounded,
          ratingCount: rating.count,
        ),
      },
  ];

  // Authorised centres first, then by rating, then alphabetically — the order a
  // driver looking for a trustworthy option wants.
  merged.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
    if (byRating != 0) return byRating;
    return a.name.compareTo(b.name);
  });

  return List<Dealer>.unmodifiable(merged);
});

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

// ── actions ───────────────────────────────────────────────────────────────

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
        .read(userWorkshopsProvider.notifier)
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

  /// Saves an edit, and refuses anything the driver does not own.
  ///
  /// The standard directory is admin-defined: an edit to it could only either
  /// be undone by the next publish or diverge silently from what every other
  /// user sees. The guard is here rather than only in the UI so no future call
  /// site can route around it.
  Future<bool> save(Dealer workshop) {
    if (!workshop.isUserAdded) return Future.value(false);
    return _run(
      () => ref.read(userWorkshopsProvider.notifier).upsert(workshop),
    );
  }

  /// Rating is the one thing allowed on a standard row: it is this device's
  /// opinion of the workshop, not a change to the workshop.
  Future<bool> rate(String id, double rating) =>
      _run(() => ref.read(dealerRatingsProvider.notifier).rate(id, rating));

  /// Same rule as [save]: only rows the driver added can be removed.
  Future<bool> remove(String id) {
    final owned = ref
        .read(userWorkshopsProvider)
        .any((workshop) => workshop.id == id);
    if (!owned) return Future.value(false);
    return _run(() => ref.read(userWorkshopsProvider.notifier).remove(id));
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final dealerControllerProvider = AsyncNotifierProvider<DealerController, void>(
  DealerController.new,
);
