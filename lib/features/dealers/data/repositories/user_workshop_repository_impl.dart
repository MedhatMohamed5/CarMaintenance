import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../../domain/entities/dealer.dart';
import '../../domain/entities/dealer_ratings.dart';
import '../../domain/repositories/user_workshop_repository.dart';
import '../models/dealer_model.dart';

class UserWorkshopRepositoryImpl implements UserWorkshopRepository {
  UserWorkshopRepositoryImpl()
    : _box = JsonBox<DealerModel>(
        boxName: HiveBoxes.dealers,
        fromJson: DealerModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<DealerModel> _box;

  /// **Filtered, not trusted.** The same box held the standard directory in an
  /// earlier version, and a device that has not yet run [purgeLegacyStandardRows]
  /// — or that fails to, because the box will not open — would otherwise show
  /// every stale published row a second time beside the live ones.
  @override
  List<Dealer> getAll() => [
    for (final workshop in _box.readAll())
      if (workshop.isUserAdded) workshop,
  ];

  @override
  Future<void> upsert(Dealer workshop) =>
      _box.put(DealerModel.fromEntity(workshop));

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<Map<String, DealerRating>> purgeLegacyStandardRows() async {
    final salvaged = <String, DealerRating>{};
    final stale = <String>[];

    for (final workshop in _box.readAll()) {
      if (workshop.isUserAdded) continue;
      stale.add(workshop.id);
      final average = workshop.rating;
      if (average != null && workshop.ratingCount > 0) {
        salvaged[workshop.id] = DealerRating(
          average: average,
          count: workshop.ratingCount,
        );
      }
    }

    for (final id in stale) {
      await _box.delete(id);
    }
    return salvaged;
  }
}
