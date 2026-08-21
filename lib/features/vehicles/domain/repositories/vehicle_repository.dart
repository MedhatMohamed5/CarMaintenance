import '../entities/vehicle.dart';

abstract interface class VehicleRepository {
  Stream<List<Vehicle>> watchVehicles();

  List<Vehicle> getVehicles();

  Vehicle? getById(String id);

  Future<void> upsert(Vehicle vehicle);

  Future<void> delete(String id);

  /// Advances the odometer, ignoring readings that would move it backwards.
  Future<void> updateOdometer(String vehicleId, int odometer);
}
