import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/remote/remote_defaults_providers.dart';
import '../../data/repositories/firestore_fuel_price_overrides.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_metric.dart';
import '../../domain/entities/fuel_price_defaults.dart';
import '../../domain/entities/fuel_stats.dart';
import '../../domain/entities/fuel_type.dart';
import 'fuel_repository_providers.dart';

export 'fuel_repository_providers.dart';

class FuelLogsNotifier extends Notifier<List<FuelLog>> {
  @override
  List<FuelLog> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(fuelRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<FuelLog>>(
        ref: ref,
        stream: repository.watchByVehicle(vehicleId),
        assign: (items) => state = _sorted(items),
      );
    }

    return _sorted(repository.getByVehicle(vehicleId));
  }

  static List<FuelLog> _sorted(List<FuelLog> logs) => [...logs]
    ..sort((a, b) {
      final byOdo = b.odometer.compareTo(a.odometer);
      return byOdo != 0 ? byOdo : b.date.compareTo(a.date);
    });

  /// Re-reads this vehicle's logs in place, for writes that went straight to
  /// the repository — a bulk import, say. Preferred over `ref.invalidate`,
  /// which tears the provider down mid-cascade.
  void reload() {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return;
    state = _sorted(ref.read(fuelRepositoryProvider).getByVehicle(vehicleId));
  }

  Future<void> upsert(FuelLog log) async {
    await ref.read(fuelRepositoryProvider).upsert(log);
    state = _sorted([...state.where((l) => l.id != log.id), log]);
  }

  Future<void> remove(String id) async {
    await ref.read(fuelRepositoryProvider).delete(id);
    state = state.where((l) => l.id != id).toList(growable: false);
  }
}

final fuelLogsProvider = NotifierProvider<FuelLogsNotifier, List<FuelLog>>(
  FuelLogsNotifier.new,
);

/// Consumption and cost, recomputed on every fuel write **and** on every
/// master-odometer update.
///
/// Watching `currentOdometer` is what keeps the figures accumulative *and*
/// live: driving 200 km without visiting the pump lengthens the span, so
/// consumption and cost per kilometre both settle downward with no new fuel
/// entry involved. Every number it produces spans the whole history — none of
/// them is scoped to the newest fill.
final fuelStatsProvider = Provider<FuelStats>((ref) {
  final logs = ref.watch(fuelLogsProvider);
  if (logs.isEmpty) return const FuelStats.empty();

  final odometer = ref.watch(
    selectedVehicleProvider.select((v) => v?.currentOdometer),
  );

  return ref.watch(calculateFuelStatsProvider)(logs, currentOdometer: odometer);
});

/// The stretch since the newest fill, or `null` when nothing has been logged.
final openTankProvider = Provider<OpenTank?>(
  (ref) => ref.watch(fuelStatsProvider).openTank,
);

/// Which unit efficiency is displayed in. L/100 km is the default; km/L is the
/// optional secondary. Persisted, because it is a reading habit, not a session
/// preference.
class FuelMetricNotifier extends Notifier<FuelMetric> {
  @override
  FuelMetric build() =>
      FuelMetric.fromName(ref.read(preferencesStoreProvider).fuelMetric);

  Future<void> select(FuelMetric metric) async {
    if (metric == state) return;
    state = metric;
    await ref.read(preferencesStoreProvider).setFuelMetric(metric.name);
  }

  Future<void> toggle() => select(state.opposite);
}

final fuelMetricProvider = NotifierProvider<FuelMetricNotifier, FuelMetric>(
  FuelMetricNotifier.new,
);

/// This account's copy of the driver's own rates, or null when signed out.
final fuelPriceOverridesStoreProvider = Provider<FirestoreFuelPriceOverrides?>((
  ref,
) {
  if (!ref.watch(isRemoteBackendProvider)) return null;
  return FirestoreFuelPriceOverrides(ref.watch(firestorePathsProvider));
});

/// The rates the driver has set for themselves — **only** those.
///
/// **Kept separate from what the app displays, and that separation is the whole
/// design.** Pre-filling a fuel entry needs published rates and personal ones
/// combined; persisting needs the personal ones alone. Storing the combined set
/// would copy today's national price into the driver's own overrides the first
/// time they touched any grade, and the next price change would then never
/// reach them — they would be pinned to a figure they never chose.
///
/// Written to preferences always, and to the account as well when there is one,
/// so a correction made on a phone shows up on the same person's tablet.
class FuelPriceOverridesNotifier extends Notifier<FuelPriceDefaults> {
  @override
  FuelPriceDefaults build() {
    // A listener rather than a `watch`: pulling is a write, and signing in is
    // the moment it has to happen.
    ref.listen<FirestoreFuelPriceOverrides?>(fuelPriceOverridesStoreProvider, (
      previous,
      next,
    ) {
      if (next != null) _pull(next);
    }, fireImmediately: true);

    return FuelPriceDefaults.fromJson(
      ref.read(preferencesStoreProvider).defaultFuelPrices,
    );
  }

  Future<void> setPrice(FuelType type, double? value) =>
      _persist(state.withPrice(type, value));

  /// Overlay grades present in [incoming]; types omitted there stay as they are.
  Future<void> merge(FuelPriceDefaults incoming) async {
    if (incoming.isEmpty) return;
    await _persist(state.mergedWith(incoming));
  }

  /// Brings the account's rates down onto a device that has not seen them.
  ///
  /// The device's own values win the merge. Someone who has just corrected a
  /// rate here and then signed in meant the correction; the account copy is
  /// older by definition, since this device has never written to it.
  Future<void> _pull(FirestoreFuelPriceOverrides store) async {
    final remote = await store.fetch();
    if (remote.isEmpty) return;
    await _persist(remote.mergedWith(state));
  }

  /// Drops every rate the driver set, putting all grades back on the
  /// admin-defined figures.
  ///
  /// **Clears rather than overwriting with today's published values.** Copying
  /// the current admin figures in would freeze them: the driver would be pinned
  /// to whatever the rate happened to be the day they pressed reset, and the
  /// next national price change would never reach them. An empty override set
  /// is what "follow the admin values" actually means, and it is also what
  /// makes the reset a no-op when there is nothing to undo.
  Future<void> reset() => _persist(FuelPriceDefaults.empty);

  Future<void> _persist(FuelPriceDefaults next) async {
    if (next == state) return;
    state = next;
    await ref
        .read(preferencesStoreProvider)
        .setDefaultFuelPrices(next.toJson());
    await ref.read(fuelPriceOverridesStoreProvider)?.save(next);
  }
}

final fuelPriceOverridesProvider =
    NotifierProvider<FuelPriceOverridesNotifier, FuelPriceDefaults>(
      FuelPriceOverridesNotifier.new,
    );

/// What every form and screen actually reads: published rates with the driver's
/// own laid over them, grade by grade.
///
/// Read-only by construction. Writing goes to [fuelPriceOverridesProvider], so
/// there is no path through which a published figure can be saved back as if
/// the driver had chosen it.
final defaultFuelPricesProvider = Provider<FuelPriceDefaults>(
  (ref) => ref
      .watch(remoteFuelPricesProvider)
      .mergedWith(ref.watch(fuelPriceOverridesProvider)),
);

final defaultFuelPriceByTypeProvider = Provider.family<double?, FuelType>(
  (ref, type) => ref.watch(defaultFuelPricesProvider).priceOf(type),
);

/// Per-log instant metrics, keyed by log id.
///
/// A log is absent from the map only when it covered no distance — the first
/// fill on record, or one entered at a reading the car had already passed.
final fuelSegmentsByLogProvider = Provider<Map<String, FuelSegment>>((ref) {
  final segments = ref.watch(fuelStatsProvider).segments;
  return {for (final s in segments) s.log.id: s};
});

final avgDailyKmProvider = Provider<double>(
  (ref) => ref.watch(fuelStatsProvider).avgDailyKm,
);

class FuelController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> addEntry({
    required DateTime date,
    required int odometer,
    required double liters,
    required FuelType fuelType,
    required double totalCost,
    bool isFullTank = true,
    String? stationName,
    String? notes,
  }) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return false;

    return _run(() async {
      final log = FuelLog(
        id: ref.read(uuidProvider).v4(),
        vehicleId: vehicleId,
        date: date,
        odometer: odometer,
        liters: liters,
        fuelType: fuelType,
        totalCost: totalCost,
        isFullTank: isFullTank,
        stationName: stationName,
        notes: notes,
      );
      await ref.read(fuelLogsProvider.notifier).upsert(log);
      await ref
          .read(vehiclesProvider.notifier)
          .updateOdometer(vehicleId, odometer);
    });
  }

  Future<bool> save(FuelLog log) =>
      _run(() => ref.read(fuelLogsProvider.notifier).upsert(log));

  Future<bool> remove(String id) =>
      _run(() => ref.read(fuelLogsProvider.notifier).remove(id));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final fuelControllerProvider = AsyncNotifierProvider<FuelController, void>(
  FuelController.new,
);
