import '../entities/saved_parking_location.dart';

/// Every car's parking history in one list, since the active pins of all cars
/// are needed together for the move-the-car reminders.
abstract interface class ParkingRepository {
  Stream<List<SavedParkingLocation>> watchAll();

  List<SavedParkingLocation> getAll();

  Future<void> upsert(SavedParkingLocation location);

  Future<void> delete(String id);

  Future<void> deleteForVehicle(String vehicleId);
}
