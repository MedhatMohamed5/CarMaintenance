import '../../domain/entities/fuel_log.dart';
import '../../domain/repositories/fuel_repository.dart';
import '../datasources/fuel_local_datasource.dart';
import '../models/fuel_log_model.dart';

class FuelRepositoryImpl implements FuelRepository {
  FuelRepositoryImpl(this._local);

  final FuelLocalDataSource _local;

  List<FuelLog> _forVehicle(List<FuelLogModel> all, String vehicleId) {
    final list = all.where((l) => l.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.odometer.compareTo(a.odometer));
    return list;
  }

  @override
  Stream<List<FuelLog>> watchByVehicle(String vehicleId) =>
      _local.watchAll().map((all) => _forVehicle(all, vehicleId));

  @override
  List<FuelLog> getByVehicle(String vehicleId) =>
      _forVehicle(_local.readAll(), vehicleId);

  @override
  Future<void> upsert(FuelLog log) => _local.put(FuelLogModel.fromEntity(log));

  @override
  Future<void> delete(String id) => _local.delete(id);

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    for (final log in _local.readAll().where((l) => l.vehicleId == vehicleId)) {
      await _local.delete(log.id);
    }
  }
}
