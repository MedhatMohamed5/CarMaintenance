import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../../domain/entities/dealer.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../datasources/dealer_seed_data.dart';
import '../models/dealer_model.dart';

class DealerRepositoryImpl implements DealerRepository {
  DealerRepositoryImpl()
    : _box = JsonBox<DealerModel>(
        boxName: HiveBoxes.dealers,
        fromJson: DealerModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<DealerModel> _box;

  /// Authorised centres first, then by rating, then alphabetically — the order
  /// a driver looking for a trustworthy option wants.
  List<Dealer> _sorted(List<DealerModel> items) {
    final list = List<Dealer>.from(items);
    list.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (byRating != 0) return byRating;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Stream<List<Dealer>> watchAll() => _box.watchAll().map(_sorted);

  @override
  List<Dealer> getAll() => _sorted(_box.readAll());

  @override
  List<Dealer> search(String query, {DealerKind? kind, String? city}) {
    final q = query.trim().toLowerCase();
    return getAll().where((d) {
      if (kind != null && d.kind != kind) return false;
      if (city != null && city.isNotEmpty && d.city != city) return false;
      if (q.isEmpty) return true;
      return [
        d.name,
        d.brand,
        d.city,
        d.address,
        d.phone,
        d.hotline,
      ].whereType<String>().any((f) => f.toLowerCase().contains(q));
    }).toList(growable: false);
  }

  @override
  Future<void> upsert(Dealer dealer) =>
      _box.put(DealerModel.fromEntity(dealer));

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<void> rate(String id, double rating) async {
    final existing = _box.readById(id);
    if (existing == null) return;
    // Running mean, so one enthusiastic tap cannot swing an established score.
    final count = existing.ratingCount;
    final current = existing.rating ?? 0;
    final next = count <= 0 ? rating : ((current * count) + rating) / (count + 1);
    await _box.put(
      DealerModel.fromEntity(
        existing.copyWith(
          rating: double.parse(next.toStringAsFixed(2)),
          ratingCount: count + 1,
        ),
      ),
    );
  }

  @override
  Future<void> syncSeedData() async {
    final existing = _box.readAll();
    final validIds = DealerSeedData.seedIds;

    for (final dealer in existing) {
      if (!dealer.isUserAdded && !validIds.contains(dealer.id)) {
        await _box.delete(dealer.id);
      }
    }

    final byId = {for (final d in existing) d.id: d};
    await _box.putAll(
      DealerSeedData.all().map((seed) {
        final previous = byId[seed.id];
        return DealerModel.fromEntity(
          previous == null
              ? seed
              : seed.copyWith(
                  rating: previous.rating,
                  ratingCount: previous.ratingCount,
                ),
        );
      }),
    );
  }
}
