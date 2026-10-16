import '../../domain/entities/saved_parking_location.dart';
import '../../domain/repositories/parking_repository.dart';
import '../datasources/parking_local_datasource.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  ParkingRepositoryImpl(this._local);

  final ParkingLocalDataSource _local;

  @override
  Stream<List<SavedParkingLocation>> watchAll() => _local.watchAll();

  @override
  List<SavedParkingLocation> getAll() => _local.readAll();

  @override
  Future<void> upsert(SavedParkingLocation location) => _local.put(location);

  @override
  Future<void> delete(String id) => _local.delete(id);

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    for (final p in _local.readAll().where((p) => p.vehicleId == vehicleId)) {
      await _local.delete(p.id);
    }
  }
}
