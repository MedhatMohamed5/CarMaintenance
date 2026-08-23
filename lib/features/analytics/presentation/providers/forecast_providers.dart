import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/vehicle_forecast.dart';
import '../../domain/usecases/compute_vehicle_forecast.dart';
import 'vehicle_metrics_provider.dart';

final computeVehicleForecastProvider = Provider<ComputeVehicleForecast>(
  (ref) => const ComputeVehicleForecast(),
);

/// Forecast for the selected vehicle, rebuilt whenever its logs, services,
/// parts or live odometer change. Empty until at least two dated odometer
/// readings span a positive distance.
final vehicleForecastProvider = Provider<VehicleForecast>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const VehicleForecast.empty();

  return ref.watch(computeVehicleForecastProvider)(
    vehicle: vehicle,
    fuelLogs: ref.watch(fuelLogsProvider),
    records: ref.watch(maintenanceRecordsProvider),
    expenses: ref.watch(expensesProvider),
    upcoming: ref
        .watch(serviceRoadmapProvider)
        .where((s) => !s.isCompleted)
        .take(8)
        .toList(growable: false),
    parts: ref.watch(partsHealthProvider),
    metrics: ref.watch(vehicleMetricsProvider),
  );
});
