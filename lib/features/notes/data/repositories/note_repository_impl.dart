import '../../domain/entities/vehicle_note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/note_local_datasource.dart';
import '../models/vehicle_note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl(this._local);

  final NoteLocalDataSource _local;

  List<VehicleNote> _forVehicle(List<VehicleNoteModel> all, String vehicleId) {
    final list = all.where((n) => n.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<VehicleNote>> watchByVehicle(String vehicleId) =>
      _local.watchAll().map((all) => _forVehicle(all, vehicleId));

  @override
  List<VehicleNote> getByVehicle(String vehicleId) =>
      _forVehicle(_local.readAll(), vehicleId);

  @override
  Future<void> upsert(VehicleNote note) =>
      _local.put(VehicleNoteModel.fromEntity(note));

  @override
  Future<void> delete(String id) => _local.delete(id);

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    for (final n in _local.readAll().where((n) => n.vehicleId == vehicleId)) {
      await _local.delete(n.id);
    }
  }
}
