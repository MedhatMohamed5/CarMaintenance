import '../fuel_math.dart';

/// How efficiency is shown to the driver.
///
/// The engine only ever computes litres per 100 km — the European standard and
/// the one that stays linear with fuel spend. km/L is a presentation choice
/// layered on top, so no calculation ever has to branch on the unit.
enum FuelMetric {
  /// Litres per 100 km. Lower is better. The default.
  litersPer100Km(unitKey: 'lPer100Km', labelKey: 'metricLPer100Km'),

  /// Kilometres per litre. Higher is better.
  kmPerLiter(unitKey: 'kmPerLiter', labelKey: 'metricKmPerLiter');

  const FuelMetric({required this.unitKey, required this.labelKey});

  /// Key for the short unit shown beside a number.
  final String unitKey;

  /// Key for the long name shown in the unit toggle.
  final String labelKey;

  static const FuelMetric fallback = FuelMetric.litersPer100Km;

  static FuelMetric fromName(String? name) => FuelMetric.values.firstWhere(
    (m) => m.name == name,
    orElse: () => fallback,
  );

  /// `true` when a bigger number is a better result, which is what colour and
  /// trend arrows key off.
  bool get higherIsBetter => this == FuelMetric.kmPerLiter;

  FuelMetric get opposite => this == FuelMetric.litersPer100Km
      ? FuelMetric.kmPerLiter
      : FuelMetric.litersPer100Km;

  /// Converts the engine's native L/100 km into this metric.
  ///
  /// The two are reciprocal (`km/L = 100 / (L/100km)`), so a zero on one side
  /// is a zero on the other rather than an infinity.
  double of(double litersPer100Km) => this == FuelMetric.litersPer100Km
      ? litersPer100Km
      : FuelMath.toKmPerLiter(litersPer100Km);

  /// Number of decimals this metric reads naturally at.
  int get decimals => 1;
}
