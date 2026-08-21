import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../models/vehicle_model.dart';

/// Offline-first source of truth for vehicles.
class VehicleLocalDataSource {
  VehicleLocalDataSource()
    : _box = JsonBox<VehicleModel>(
        boxName: HiveBoxes.vehicles,
        fromJson: VehicleModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<VehicleModel> _box;

  Stream<List<VehicleModel>> watchAll() => _box.watchAll();

  List<VehicleModel> readAll() => _box.readAll();

  VehicleModel? readById(String id) => _box.readById(id);

  Future<void> put(VehicleModel model) => _box.put(model);

  Future<void> delete(String id) => _box.delete(id);
}
