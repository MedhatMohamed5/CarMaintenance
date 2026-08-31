import '../../features/dealers/data/models/dealer_model.dart';
import '../../features/dealers/domain/entities/dealer.dart';
import '../../features/fuel/domain/entities/fuel_price_defaults.dart';

/// The values the app ships with, as published rather than as compiled in.
///
/// **Two things in this app go stale on a timescale the release cycle cannot
/// follow.** Egyptian pump prices move by government decision, sometimes twice
/// in a year; the workshop directory gains and loses branches continuously.
/// Both were baked into the binary, so correcting either meant a store release
/// and then waiting weeks for people to take it — during which the app
/// confidently pre-filled a fuel entry with last year's rate.
///
/// This is the published copy of both. It is *defaults only*: anything the
/// driver has set for themselves wins, always, and nothing here overwrites it.
/// See `fuelPriceOverridesProvider` and [Dealer.isUserEdited] for the two
/// override paths.
class RemoteDefaults {
  const RemoteDefaults({
    this.version = 0,
    this.fuelPrices = FuelPriceDefaults.empty,
    this.workshops = const [],
  });

  static const empty = RemoteDefaults();

  /// Bumped by whoever publishes the document. Carried so a cached copy can be
  /// compared against a fetched one without diffing the contents.
  final int version;

  final FuelPriceDefaults fuelPrices;

  /// The directory as published. Rows keep their ids across publishes, which is
  /// what lets a driver's edit to one survive the next update.
  final List<Dealer> workshops;

  bool get isEmpty => fuelPrices.isEmpty && workshops.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': version,
    'fuelPrices': fuelPrices.toJson(),
    'workshops': [
      for (final w in workshops) DealerModel.fromEntity(w).toJson(),
    ],
  };

  /// Tolerant by construction: a malformed row is dropped, not fatal.
  ///
  /// This parses a document the app does not control the write side of. One bad
  /// entry — a typo in a published record, a field renamed by hand in the
  /// console — must not cost the driver the other forty, and must never cost
  /// them the fuel prices in the same document.
  factory RemoteDefaults.fromJson(Map<String, dynamic> json) {
    final workshops = <Dealer>[];
    final raw = json['workshops'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        if (map['id'] is! String || (map['id'] as String).isEmpty) continue;
        try {
          // Published rows are never the driver's own, whatever the document
          // claims — the two flags are what protect a local edit from being
          // overwritten on the next publish.
          workshops.add(
            DealerModel.fromJson(
              map,
            ).copyWith(isUserAdded: false, isUserEdited: false),
          );
        } on Object {
          continue;
        }
      }
    }

    return RemoteDefaults(
      version: switch (json['version']) {
        final int v => v,
        final num v => v.toInt(),
        _ => 0,
      },
      fuelPrices: FuelPriceDefaults.fromJson(json['fuelPrices']),
      workshops: List<Dealer>.unmodifiable(workshops),
    );
  }
}
