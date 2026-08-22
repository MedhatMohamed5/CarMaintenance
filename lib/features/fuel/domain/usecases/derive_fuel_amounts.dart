import '../fuel_math.dart';

/// Which of the three money fields the user is currently editing.
enum FuelAmountField { liters, pricePerLiter, totalCost }

/// The cost/volume/price triangle as plain data. A `null` field is one the
/// user has not filled in yet — distinct from a zero they typed themselves.
class FuelAmounts {
  const FuelAmounts({this.liters, this.pricePerLiter, this.totalCost});

  final double? liters;
  final double? pricePerLiter;
  final double? totalCost;

  FuelAmounts copyWith({
    double? liters,
    double? pricePerLiter,
    double? totalCost,
  }) => FuelAmounts(
    liters: liters ?? this.liters,
    pricePerLiter: pricePerLiter ?? this.pricePerLiter,
    totalCost: totalCost ?? this.totalCost,
  );

  double? operator [](FuelAmountField field) => switch (field) {
    FuelAmountField.liters => liters,
    FuelAmountField.pricePerLiter => pricePerLiter,
    FuelAmountField.totalCost => totalCost,
  };

  @override
  String toString() =>
      'FuelAmounts(liters: $liters, price: $pricePerLiter, cost: $totalCost)';
}

/// Completes the triangle from whichever two values are known.
///
/// The field being edited is **never** written back — that is what keeps the
/// form from fighting the keyboard. Everything else follows the matrix:
///
///   cost + price   -> volume = cost / price
///   volume + price -> cost   = volume * price
///   cost + volume  -> price  = cost / volume
///
/// Price per litre is the pump-posted constant, so when an edit could be
/// resolved two ways the rule that holds the price steady wins.
class DeriveFuelAmounts {
  const DeriveFuelAmounts();

  FuelAmounts call({
    required FuelAmounts input,
    required FuelAmountField edited,
  }) => switch (edited) {
    FuelAmountField.liters => _fromLiters(input),
    FuelAmountField.pricePerLiter => _fromPrice(input),
    FuelAmountField.totalCost => _fromCost(input),
  };

  FuelAmounts _fromLiters(FuelAmounts a) {
    final liters = a.liters;
    if (!_positive(liters)) return a;
    if (_positive(a.pricePerLiter)) {
      return a.copyWith(
        totalCost: _round(
          FuelMath.totalCost(liters: liters!, pricePerLiter: a.pricePerLiter!),
        ),
      );
    }
    if (_positive(a.totalCost)) {
      return a.copyWith(
        pricePerLiter: _round(
          FuelMath.pricePerLiter(totalCost: a.totalCost!, liters: liters!),
        ),
      );
    }
    return a;
  }

  FuelAmounts _fromPrice(FuelAmounts a) {
    final price = a.pricePerLiter;
    if (!_positive(price)) return a;
    if (_positive(a.liters)) {
      return a.copyWith(
        totalCost: _round(
          FuelMath.totalCost(liters: a.liters!, pricePerLiter: price!),
        ),
      );
    }
    if (_positive(a.totalCost)) {
      return a.copyWith(
        liters: _round(
          FuelMath.liters(totalCost: a.totalCost!, pricePerLiter: price!),
        ),
      );
    }
    return a;
  }

  FuelAmounts _fromCost(FuelAmounts a) {
    final cost = a.totalCost;
    if (!_positive(cost)) return a;
    if (_positive(a.pricePerLiter)) {
      return a.copyWith(
        liters: _round(
          FuelMath.liters(totalCost: cost!, pricePerLiter: a.pricePerLiter!),
        ),
      );
    }
    if (_positive(a.liters)) {
      return a.copyWith(
        pricePerLiter: _round(
          FuelMath.pricePerLiter(totalCost: cost!, liters: a.liters!),
        ),
      );
    }
    return a;
  }

  static bool _positive(double? v) => v != null && v > 0 && v.isFinite;

  /// Money and volume are only ever meaningful to two decimals; rounding here
  /// stops `19.999999999999996` from reaching a text field.
  static double? _round(double value) {
    if (!value.isFinite || value <= 0) return null;
    return (value * 100).round() / 100;
  }
}
