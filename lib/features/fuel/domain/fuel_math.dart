/// The single source of truth for every fuel and running-cost formula in the
/// app. Nothing else divides litres, money or kilometres by hand.
///
/// Worked example, one fill of 1718 over 609 km at 22.25 per litre:
///
/// ```
/// liters        = 1718 / 22.25        = 77.21 L
/// costPerKm     = 1718 / 609          =  2.82 /km
/// litersPer100Km = (77.21 / 609) * 100 = 12.68 L/100km   <- primary
/// kmPerLiter    = 609 / 77.21         =  7.89 km/L       <- secondary
/// ```
///
/// Every entry point routes through [safeDivide], so a zero distance, a zero
/// price or a zero volume yields `0.0` rather than `NaN` or `Infinity`. That
/// makes every result safe to format, plot and compare without a caller-side
/// guard, and it is why no formula here needs a nullable return.
class FuelMath {
  const FuelMath._();

  /// Guarded division. Returns `0.0` for a non-positive denominator, and for
  /// any result that is not a finite positive number.
  ///
  /// Negative results collapse to zero deliberately: a negative consumption or
  /// a negative cost per kilometre is a data error, not a measurement, and
  /// surfacing it as a number invites it into a chart axis.
  static double safeDivide(num numerator, num denominator) {
    if (denominator <= 0) return 0;
    final value = numerator / denominator;
    return value.isFinite && value > 0 ? value.toDouble() : 0;
  }

  // ---- the pump: cost, volume, unit price -----------------------------

  /// `Liters = Total Cost / Price Per Liter`
  static double liters({
    required double totalCost,
    required double pricePerLiter,
  }) => safeDivide(totalCost, pricePerLiter);

  /// `Price Per Liter = Total Cost / Liters`
  static double pricePerLiter({
    required double totalCost,
    required double liters,
  }) => safeDivide(totalCost, liters);

  /// `Total Cost = Liters * Price Per Liter`
  ///
  /// The one formula that multiplies rather than divides; it is here so the
  /// triangle stays in one place and picks up the same non-negative guard.
  static double totalCost({
    required double liters,
    required double pricePerLiter,
  }) {
    if (liters <= 0 || pricePerLiter <= 0) return 0;
    final value = liters * pricePerLiter;
    return value.isFinite && value > 0 ? value : 0;
  }

  // ---- the road: distance-based rates ---------------------------------

  /// `Cost Per KM = Total Cost / Distance Traveled`
  static double costPerKm({
    required double totalCost,
    required num distanceKm,
  }) => safeDivide(totalCost, distanceKm);

  /// `L/100km = (Total Liters / Distance Traveled) * 100` — the primary,
  /// European economy metric. Lower is better.
  static double litersPer100Km({
    required double liters,
    required num distanceKm,
  }) => safeDivide(liters * 100, distanceKm);

  /// `KM/L = Distance Traveled / Total Liters` — the secondary metric.
  /// Higher is better.
  static double kmPerLiter({required double liters, required num distanceKm}) =>
      safeDivide(distanceKm, liters);

  /// Distance covered per day, the input that turns a service target into a
  /// date.
  static double kmPerDay({required num distanceKm, required int days}) =>
      safeDivide(distanceKm, days);

  /// Mean Gregorian month used when scaling a daily figure to a monthly one.
  static const double daysPerMeanMonth = 30.44;

  /// Lifetime kilometres per month from an observed distance and calendar span.
  ///
  /// `distance / max(days / 30.44, 1)`. A window shorter than one mean month
  /// is not scaled up, so the monthly average cannot exceed kilometres
  /// actually accumulated.
  static double kmPerMonth({required num distanceKm, required int days}) {
    final elapsed = days < 1 ? 1 : days;
    final months = elapsed / daysPerMeanMonth;
    return safeDivide(distanceKm, months < 1 ? 1 : months);
  }

  // ---- unit conversion -------------------------------------------------

  /// The two economy units are reciprocal about 100, so one conversion serves
  /// both directions: `km/L = 100 / (L/100km)` and the inverse.
  static double toKmPerLiter(double litersPer100Km) =>
      safeDivide(100, litersPer100Km);

  static double toLitersPer100Km(double kmPerLiter) =>
      safeDivide(100, kmPerLiter);

  /// Distance travelled between two odometer readings, floored at zero so a
  /// back-dated or mistyped entry can never produce a negative denominator.
  static int distanceBetween(int fromOdometer, int toOdometer) {
    final driven = toOdometer - fromOdometer;
    return driven > 0 ? driven : 0;
  }
}

/// Shorthand for [FuelMath.safeDivide], for the many places that read better
/// as a bare ratio than as a named formula.
double safeRate(num numerator, num denominator) =>
    FuelMath.safeDivide(numerator, denominator);
