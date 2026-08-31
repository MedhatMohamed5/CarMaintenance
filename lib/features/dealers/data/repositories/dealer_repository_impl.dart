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
    return getAll()
        .where((d) {
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
        })
        .toList(growable: false);
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
    final next = count <= 0
        ? rating
        : ((current * count) + rating) / (count + 1);
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
  String get authorizedHotline => DealerSeedData.ezzElarabHotline;

  /// Rewrites the published half of the directory and leaves the driver's half
  /// alone.
  ///
  /// Three rules, in order:
  ///
  ///  1. A row the driver **owns** — added or edited — is never deleted and
  ///     never overwritten, whatever the publish says. That is the whole point
  ///     of [Dealer.isUserOwned]: without it, a correction survives until the
  ///     next refresh and then quietly reverts.
  ///  2. A published row that is no longer published is removed, so a closed
  ///     branch actually disappears.
  ///  3. A published row that is still published is replaced, except for its
  ///     rating — that is the driver's, earned on this device, and re-publishing
  ///     an address should not reset it.
  @override
  Future<void> syncDefaults(List<Dealer> defaults) async {
    if (defaults.isEmpty) return;

    final existing = _box.readAll();
    final publishedIds = {for (final d in defaults) d.id};

    for (final dealer in existing) {
      if (dealer.isUserOwned) continue;
      if (!publishedIds.contains(dealer.id)) await _box.delete(dealer.id);
    }

    final byId = {for (final d in existing) d.id: d};
    await _box.putAll([
      for (final published in defaults)
        if (!(byId[published.id]?.isUserOwned ?? false))
          DealerModel.fromEntity(switch (byId[published.id]) {
            null => published,
            final previous => published.copyWith(
              rating: previous.rating,
              ratingCount: previous.ratingCount,
            ),
          }),
    ]);
  }
}
