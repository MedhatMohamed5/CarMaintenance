import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../domain/entities/fuel_price_defaults.dart';

/// The pump rates the driver set for themselves, in their account.
///
/// **A setting, not a log, so it is one document rather than a collection.**
/// There is exactly one set of rates per account and it is overwritten whole
/// every time; giving each grade its own document would buy nothing and cost
/// four reads.
///
/// What is stored here is only the driver's own corrections. The published
/// rates are fetched separately and are the same for everyone — writing those
/// into every account would pin each driver to whatever the rate happened to be
/// on the day they installed, and a later national price change would never
/// reach them.
class FirestoreFuelPriceOverrides {
  const FirestoreFuelPriceOverrides(this._paths);

  final FirestorePaths _paths;

  static const String document = 'fuel_prices';

  /// This account's rates, or empty when there are none and when the read
  /// fails. The caller layers whatever comes back over values it already has,
  /// so an empty answer and a failed one call for the same behaviour.
  Future<FuelPriceDefaults> fetch() async {
    try {
      final snapshot = await _paths.settings.doc(document).get();
      final data = snapshot.data();
      if (data == null) return FuelPriceDefaults.empty;
      return FuelPriceDefaults.fromJson(data['prices']);
    } on Object {
      return FuelPriceDefaults.empty;
    }
  }

  Future<void> save(FuelPriceDefaults prices) => fireAndForget(
    _paths.settings.doc(document).set({
      'prices': prices.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    }),
    label: 'fuel price defaults',
  );
}
