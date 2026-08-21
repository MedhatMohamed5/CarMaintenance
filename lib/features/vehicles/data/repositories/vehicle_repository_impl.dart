import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../datasources/vehicle_local_datasource.dart';
import '../models/vehicle_model.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl(this._local);

  final VehicleLocalDataSource _local;

  List<Vehicle> _sorted(List<VehicleModel> items) {
    final list = List<Vehicle>.from(items);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Stream<List<Vehicle>> watchVehicles() => _local.watchAll().map(_sorted);

  @override
  List<Vehicle> getVehicles() => _sorted(_local.readAll());

  @override
  Vehicle? getById(String id) => _local.readById(id);

  @override
  Future<void> upsert(Vehicle vehicle) =>
      _local.put(VehicleModel.fromEntity(vehicle));

  @override
  Future<void> delete(String id) => _local.delete(id);

  @override
  Future<void> updateOdometer(String vehicleId, int odometer) async {
    final current = _local.readById(vehicleId);
    if (current == null) return;
    // Odometers only ever move forward; a lower reading is a typo, not a fact.
    if (odometer <= current.currentOdometer) return;
    await _local.put(
      VehicleModel.fromEntity(
        current.copyWith(
          currentOdometer: odometer,
          odometerUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }
}
