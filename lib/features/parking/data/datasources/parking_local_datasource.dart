import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../../domain/entities/saved_parking_location.dart';

class ParkingLocalDataSource {
  ParkingLocalDataSource()
    : _box = JsonBox<SavedParkingLocation?>(
        boxName: HiveBoxes.parking,
        // fromJson answers null for a record it cannot read; those are skipped
        // rather than failing the whole history.
        fromJson: SavedParkingLocation.fromJson,
        toJson: (v) => v!.toJson(),
        idOf: (v) => v!.id,
      );

  final JsonBox<SavedParkingLocation?> _box;

  Stream<List<SavedParkingLocation>> watchAll() =>
      _box.watchAll().map((all) => all.nonNulls.toList(growable: false));

  List<SavedParkingLocation> readAll() =>
      _box.readAll().nonNulls.toList(growable: false);

  Future<void> put(SavedParkingLocation location) => _box.put(location);

  Future<void> delete(String id) => _box.delete(id);
}
