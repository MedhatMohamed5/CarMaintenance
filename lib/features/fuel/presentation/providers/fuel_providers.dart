import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_metric.dart';
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
