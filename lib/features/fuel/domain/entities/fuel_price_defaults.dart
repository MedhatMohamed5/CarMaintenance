import 'package:equatable/equatable.dart';

import 'fuel_type.dart';

/// Pump-posted defaults, one rate per grade.
///
/// These pre-fill a new fuel entry; they are never stored on a log. A log
/// keeps quantity and total cost, and derives the unit price from those two.
class FuelPriceDefaults extends Equatable {
  const FuelPriceDefaults._(this._prices);

  static const empty = FuelPriceDefaults._({});

  final Map<String, double> _prices;

  bool get isEmpty => _prices.isEmpty;

  double? priceOf(FuelType type) {
    final value = _prices[type.name];
    if (value == null || value <= 0 || !value.isFinite) return null;
    return value;
  }

  FuelPriceDefaults withPrice(FuelType type, double? price) {
    final next = <String, double>{..._prices};
    final value = _positive(price);
    if (value == null) {
      next.remove(type.name);
    } else {
      next[type.name] = value;
    }
    return FuelPriceDefaults._(next);
  }

  /// This set with [other] laid over it, grade by grade.
  ///
  /// **Per grade, not whole-set.** The driver may have corrected the 92 rate at
  /// their own station and left 95 and diesel alone; replacing the whole set
  /// with theirs would drop the published figures for the two they never
  /// touched, and replacing theirs with the published set would silently undo
  /// the correction. Only the grades [other] actually carries win.
  FuelPriceDefaults mergedWith(FuelPriceDefaults other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return FuelPriceDefaults._({..._prices, ...other._prices});
  }

  Map<String, double> toJson() => Map<String, double>.from(_prices);

  factory FuelPriceDefaults.fromJson(Object? value) {
    if (value is! Map) return empty;
    final prices = <String, double>{};
    for (final type in FuelType.values) {
      final parsed = _positive(value[type.name]);
      if (parsed != null) prices[type.name] = parsed;
    }
    if (!prices.containsKey(FuelType.naturalGas.name)) {
      final alias = _positive(value['cng']) ?? _positive(value['CNG']);
      if (alias != null) prices[FuelType.naturalGas.name] = alias;
    }
    return prices.isEmpty ? empty : FuelPriceDefaults._(prices);
  }

  static double? _positive(Object? value) {
    final parsed = switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    if (parsed == null || parsed <= 0 || !parsed.isFinite) return null;
    return parsed;
  }

  @override
  List<Object?> get props => [
    for (final type in FuelType.values) _prices[type.name],
  ];
}
