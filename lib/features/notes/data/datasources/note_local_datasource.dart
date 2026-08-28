import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../models/vehicle_note_model.dart';

class NoteLocalDataSource {
  NoteLocalDataSource()
    : _box = JsonBox<VehicleNoteModel>(
        boxName: HiveBoxes.notes,
        fromJson: VehicleNoteModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<VehicleNoteModel> _box;

  Stream<List<VehicleNoteModel>> watchAll() => _box.watchAll();

  List<VehicleNoteModel> readAll() => _box.readAll();

  Future<void> put(VehicleNoteModel model) => _box.put(model);

  Future<void> delete(String id) => _box.delete(id);
}
