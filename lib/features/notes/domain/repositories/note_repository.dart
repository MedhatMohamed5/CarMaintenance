import '../entities/vehicle_note.dart';

abstract interface class NoteRepository {
  /// Newest first.
  Stream<List<VehicleNote>> watchByVehicle(String vehicleId);

  List<VehicleNote> getByVehicle(String vehicleId);

  Future<void> upsert(VehicleNote note);

  Future<void> delete(String id);

  Future<void> deleteForVehicle(String vehicleId);
}
