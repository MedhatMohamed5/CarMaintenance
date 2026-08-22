import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/vehicle_metrics.dart';

/// The unified figure source for every screen.
///
/// Home, the fuel tab, the analytics grid, the efficiency gauge and the
/// exported report all watch this. None of them recompute anything, so they
/// cannot drift apart.
///
/// Recomputes whenever any input moves — a fill, a service, a part, an
/// expense, or a master-odometer update — because the distance denominator is
/// read live from the vehicle rather than from the newest fuel log.
final vehicleMetricsProvider = Provider<VehicleMetrics>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const VehicleMetrics.empty();

  final fuel = ref.watch(fuelStatsProvider);
  final cost = ref.watch(totalCostProvider);
  final logs = ref.watch(fuelLogsProvider);

  return VehicleMetrics(
    // Initial odometer to current odometer: the ownership delta, not the span
    // between fuel logs.
    trackedDistanceKm: cost.trackedDistanceKm,
    // The fuel engine's own accumulative span — first fill to the live
    // odometer — not a second, differently-derived distance.
    fuelDistanceKm: fuel.liveDistanceKm,
    totalLiters: fuel.totalLiters,
    fuelCost: cost.fuel,
    serviceCost: cost.service,
    partsCost: cost.parts,
    otherCost: cost.other,
    fillCount: logs.length,
    serviceCount: ref.watch(billableServiceRecordsProvider).length,
    expenseCount: ref.watch(expensesProvider).length,
    firstLogDate: fuel.firstLogDate,
    lastLogDate: fuel.lastLogDate,
    avgDailyKm: fuel.avgDailyKm,
    // Straight from the engine. The per-grade rows were already right; nothing
    // is re-derived or re-allocated here.
    byFuelType: fuel.byFuelType,
  );
});

/// Accumulative consumption in L/100 km — the primary metric, identical on
/// every screen that shows it.
final unifiedLitersPer100KmProvider = Provider<double>(
  (ref) => ref.watch(vehicleMetricsProvider).litersPer100Km,
);

/// Fuel spend per kilometre over the whole tracked distance.
final unifiedFuelCostPerKmProvider = Provider<double>(
  (ref) => ref.watch(vehicleMetricsProvider).fuelCostPerKm,
);

/// Every cost stream per kilometre over the whole tracked distance.
final unifiedTotalCostPerKmProvider = Provider<double>(
  (ref) => ref.watch(vehicleMetricsProvider).totalCostPerKm,
);
