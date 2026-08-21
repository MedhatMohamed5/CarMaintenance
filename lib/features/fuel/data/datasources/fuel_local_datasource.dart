import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../models/fuel_log_model.dart';

class FuelLocalDataSource {
  FuelLocalDataSource()
    : _box = JsonBox<FuelLogModel>(
        boxName: HiveBoxes.fuelLogs,
        fromJson: FuelLogModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<FuelLogModel> _box;

  Stream<List<FuelLogModel>> watchAll() => _box.watchAll();

  List<FuelLogModel> readAll() => _box.readAll();

  Future<void> put(FuelLogModel model) => _box.put(model);

  Future<void> delete(String id) => _box.delete(id);
}
