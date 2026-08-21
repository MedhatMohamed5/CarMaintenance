import '../entities/fuel_log.dart';

abstract interface class FuelRepository {
  /// Newest first, filtered to one vehicle.
  Stream<List<FuelLog>> watchByVehicle(String vehicleId);

  List<FuelLog> getByVehicle(String vehicleId);

  Future<void> upsert(FuelLog log);

  Future<void> delete(String id);

  Future<void> deleteForVehicle(String vehicleId);
}
