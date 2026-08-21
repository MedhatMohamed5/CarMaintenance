import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../data/repositories/dealer_repository_impl.dart';
import '../../domain/entities/dealer.dart';
import '../../domain/repositories/dealer_repository.dart';

final dealerRepositoryProvider = Provider<DealerRepository>(
  (ref) => DealerRepositoryImpl(),
);

class DealersNotifier extends Notifier<List<Dealer>> {
  @override
  List<Dealer> build() => ref.read(dealerRepositoryProvider).getAll();

  void _refresh() => state = ref.read(dealerRepositoryProvider).getAll();

  Future<void> upsert(Dealer dealer) async {
    await ref.read(dealerRepositoryProvider).upsert(dealer);
    _refresh();
  }

  Future<void> rate(String id, double rating) async {
    await ref.read(dealerRepositoryProvider).rate(id, rating);
    _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(dealerRepositoryProvider).delete(id);
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

  return all.where((d) {
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
  }).toList(growable: false);
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

  Future<bool> save(Dealer dealer) =>
      _run(() => ref.read(dealersProvider.notifier).upsert(dealer));

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
