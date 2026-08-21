import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/next_service_due.dart';
import '../../domain/entities/part_health.dart';
import '../../domain/entities/part_replacement.dart';
import '../../domain/entities/service_milestone.dart';
import '../../domain/entities/upcoming_service.dart';
import 'maintenance_repository_providers.dart';

export 'maintenance_repository_providers.dart';

class MaintenanceRecordsNotifier extends Notifier<List<MaintenanceRecord>> {
  @override
  List<MaintenanceRecord> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(maintenanceRepositoryProvider);
    final subscription = repository
        .watchRecords(vehicleId)
        .listen((items) => state = _sorted(items));
    ref.onDispose(subscription.cancel);

    return _sorted(repository.getRecords(vehicleId));
  }

  static List<MaintenanceRecord> _sorted(List<MaintenanceRecord> items) =>
      [...items]..sort((a, b) => b.odometer.compareTo(a.odometer));

  Future<void> upsert(MaintenanceRecord record) async {
    await ref.read(maintenanceRepositoryProvider).saveService(record);
    state = _sorted([...state.where((r) => r.id != record.id), record]);
    ref.invalidate(partReplacementsProvider);
  }

  Future<void> remove(String id) async {
    await ref.read(maintenanceRepositoryProvider).deleteRecord(id);
    state = state.where((r) => r.id != id).toList(growable: false);
    ref.invalidate(partReplacementsProvider);
  }
}

final maintenanceRecordsProvider =
    NotifierProvider<MaintenanceRecordsNotifier, List<MaintenanceRecord>>(
      MaintenanceRecordsNotifier.new,
    );

class PartReplacementsNotifier extends Notifier<List<PartReplacement>> {
  @override
  List<PartReplacement> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(maintenanceRepositoryProvider);
    final subscription = repository
        .watchReplacements(vehicleId)
        .listen((items) => state = items);
    ref.onDispose(subscription.cancel);

    return repository.getReplacements(vehicleId);
  }

  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
  }) async {
    await ref
        .read(maintenanceRepositoryProvider)
        .resetPart(vehicleId: vehicleId, part: part, odometer: odometer);
    state = ref
        .read(maintenanceRepositoryProvider)
        .getReplacements(vehicleId);
  }
}

final partReplacementsProvider =
    NotifierProvider<PartReplacementsNotifier, List<PartReplacement>>(
      PartReplacementsNotifier.new,
    );

final partsHealthProvider = Provider<List<PartHealth>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(calculatePartsHealthProvider)(
    vehicle: vehicle,
    replacements: ref.watch(partReplacementsProvider),
    avgDailyKm: ref.watch(avgDailyKmProvider),
  );
});

final allPartsHealthProvider = Provider<List<PartHealth>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(calculatePartsHealthProvider)(
    vehicle: vehicle,
    replacements: ref.watch(partReplacementsProvider),
    parts: ConsumablePart.values,
    avgDailyKm: ref.watch(avgDailyKmProvider),
  );
});

final serviceRoadmapProvider = Provider<List<UpcomingService>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(predictServicesProvider)(
    vehicle: vehicle,
    records: ref.watch(maintenanceRecordsProvider),
    avgDailyKmFromFuel: ref.watch(avgDailyKmProvider),
  );
});

final nextServiceDueProvider = Provider<NextServiceDue?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;
  return ref
      .watch(predictServicesProvider)
      .nextDue(
        vehicle: vehicle,
        records: ref.watch(maintenanceRecordsProvider),
        avgDailyKmFromFuel: ref.watch(avgDailyKmProvider),
      );
});

final lastServiceProvider = Provider<MaintenanceRecord?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;
  return ref
      .watch(predictServicesProvider)
      .lastPerformed(ref.watch(maintenanceRecordsProvider), vehicle.id);
});

final upcomingServicesProvider = Provider<List<UpcomingService>>(
  (ref) => ref
      .watch(serviceRoadmapProvider)
      .where((s) => !s.isCompleted)
      .take(3)
      .toList(growable: false),
);

final dailyPaceProvider = Provider<double>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return 0;
  return ref
      .watch(predictServicesProvider)
      .dailyPace(
        vehicle: vehicle,
        avgDailyKmFromFuel: ref.watch(avgDailyKmProvider),
      );
});

final monthlyPaceProvider = Provider<double>(
  (ref) => ref.watch(dailyPaceProvider) * 30.44,
);

class MaintenanceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> logService({
    required DateTime date,
    required int odometer,
    required String title,
    required ServiceTier tier,
    List<ConsumablePart> replacedParts = const [],
    List<String> inspectedKeys = const [],
    List<String> customItems = const [],
    double cost = 0,
    String? workshopName,
    String? notes,
    int? milestoneOdometer,
  }) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return false;

    return _run(() async {
      await ref
          .read(maintenanceRecordsProvider.notifier)
          .upsert(
            MaintenanceRecord(
              id: ref.read(uuidProvider).v4(),
              vehicleId: vehicleId,
              date: date,
              odometer: odometer,
              title: title,
              tier: tier,
              replacedParts: replacedParts,
              inspectedKeys: inspectedKeys,
              customItems: customItems,
              cost: cost,
              workshopName: workshopName,
              notes: notes,
              milestoneOdometer: milestoneOdometer,
            ),
          );
      await ref
          .read(vehiclesProvider.notifier)
          .updateOdometer(vehicleId, odometer);
    });
  }

  Future<bool> save(MaintenanceRecord record) =>
      _run(() => ref.read(maintenanceRecordsProvider.notifier).upsert(record));

  Future<bool> remove(String id) =>
      _run(() => ref.read(maintenanceRecordsProvider.notifier).remove(id));

  Future<bool> resetPart(ConsumablePart part, {int? odometer}) async {
    final vehicle = ref.read(selectedVehicleProvider);
    if (vehicle == null) return false;

    return _run(
      () => ref
          .read(partReplacementsProvider.notifier)
          .resetPart(
            vehicleId: vehicle.id,
            part: part,
            odometer: odometer ?? vehicle.currentOdometer,
          ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final maintenanceControllerProvider =
    AsyncNotifierProvider<MaintenanceController, void>(
      MaintenanceController.new,
    );
