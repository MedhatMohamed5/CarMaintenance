import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../expenses/presentation/providers/expense_repository_providers.dart';
import '../../../fuel/presentation/providers/fuel_repository_providers.dart';
import '../../../maintenance/presentation/providers/maintenance_repository_providers.dart';
import '../../data/datasources/vehicle_local_datasource.dart';
import '../../data/repositories/firestore_vehicle_repository.dart';
import '../../data/repositories/vehicle_repository_impl.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';

final vehicleLocalDataSourceProvider = Provider<VehicleLocalDataSource>(
  (ref) => VehicleLocalDataSource(),
);

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreVehicleRepository(
      ref.watch(firestorePathsProvider),
      mirror: VehicleRepositoryImpl(ref.watch(vehicleLocalDataSourceProvider)),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return VehicleRepositoryImpl(ref.watch(vehicleLocalDataSourceProvider));
});

class VehiclesNotifier extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() {
    final repository = ref.watch(vehicleRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<Vehicle>>(
        ref: ref,
        stream: repository.watchVehicles(),
        assign: (items) => state = _sorted(items),
      );
    }
    return _sorted(repository.getVehicles());
  }

  static List<Vehicle> _sorted(List<Vehicle> items) =>
      [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> upsert(Vehicle vehicle) async {
    await ref.read(vehicleRepositoryProvider).upsert(vehicle);
    state = _sorted([...state.where((v) => v.id != vehicle.id), vehicle]);
  }

  /// Re-reads the garage in place after a bulk write that went straight to
  /// the repository — a vehicle import, for example.
  void reload() {
    state = _sorted(ref.read(vehicleRepositoryProvider).getVehicles());
  }

  Future<void> remove(String id) async {
    await ref.read(vehicleRepositoryProvider).delete(id);
    state = state.where((v) => v.id != id).toList(growable: false);
  }

  Future<void> updateOdometer(String vehicleId, int odometer) async {
    // Read through the repository rather than `state`: touching `state` from a
    // mutation can force a build while one is already in flight.
    final current = ref.read(vehicleRepositoryProvider).getById(vehicleId);
    if (current == null || odometer <= current.currentOdometer) return;
    await upsert(
      current.copyWith(
        currentOdometer: odometer,
        odometerUpdatedAt: DateTime.now(),
      ),
    );
  }
}

final vehiclesProvider = NotifierProvider<VehiclesNotifier, List<Vehicle>>(
  VehiclesNotifier.new,
);

class SelectedVehicleIdNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(preferencesStoreProvider).selectedVehicleId;

  Future<void> select(String? id) async {
    state = id;
    await ref.read(preferencesStoreProvider).setSelectedVehicleId(id);
  }
}

final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleIdNotifier, String?>(
      SelectedVehicleIdNotifier.new,
    );

final selectedVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesProvider);
  if (vehicles.isEmpty) return null;
  final id = ref.watch(selectedVehicleIdProvider);
  return vehicles.firstWhere((v) => v.id == id, orElse: () => vehicles.first);
});

final selectedVehicleIdOrFirstProvider = Provider<String?>(
  (ref) => ref.watch(selectedVehicleProvider)?.id,
);

class VehicleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [initialOdometer] is the baseline every accumulative metric measures
  /// from; [currentOdometer] is where the car stands today. They are separate
  /// on purpose — a used car joins the app with distance already behind it.
  Future<bool> add({
    required String make,
    required String model,
    required int year,
    required int initialOdometer,
    required int currentOdometer,
    String? nickname,
    String? plateNumber,
    DateTime? purchaseDate,
    DateTime? licenseExpiry,
    DateTime? insuranceExpiry,
    double? tankCapacityLiters,
    int? colorValue,
    String? imageBase64,
  }) => _run(() async {
    final id = ref.read(uuidProvider).v4();
    await ref
        .read(vehiclesProvider.notifier)
        .upsert(
          Vehicle(
            id: id,
            make: make.trim(),
            model: model.trim(),
            year: year,
            initialOdometer: initialOdometer,
            currentOdometer: currentOdometer < initialOdometer
                ? initialOdometer
                : currentOdometer,
            createdAt: DateTime.now(),
            nickname: nickname?.trim(),
            plateNumber: plateNumber?.trim(),
            purchaseDate: purchaseDate,
            licenseExpiry: licenseExpiry,
            insuranceExpiry: insuranceExpiry,
            tankCapacityLiters: tankCapacityLiters,
            colorValue: colorValue,
            imageBase64: imageBase64,
            odometerUpdatedAt: DateTime.now(),
          ),
        );
    await ref.read(selectedVehicleIdProvider.notifier).select(id);
  });

  Future<bool> save(Vehicle vehicle) =>
      _run(() => ref.read(vehiclesProvider.notifier).upsert(vehicle));

  Future<bool> updateOdometer(String vehicleId, int odometer) => _run(
    () =>
        ref.read(vehiclesProvider.notifier).updateOdometer(vehicleId, odometer),
  );

  Future<bool> remove(String id) => _run(() async {
    await ref.read(fuelRepositoryProvider).deleteForVehicle(id);
    await ref.read(maintenanceRepositoryProvider).deleteForVehicle(id);
    await ref.read(expenseRepositoryProvider).deleteForVehicle(id);
    await ref.read(vehiclesProvider.notifier).remove(id);
    if (ref.read(selectedVehicleIdProvider) == id) {
      await ref.read(selectedVehicleIdProvider.notifier).select(null);
    }
  });

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final vehicleControllerProvider =
    AsyncNotifierProvider<VehicleController, void>(VehicleController.new);
