import 'package:equatable/equatable.dart';

import 'fuel_type.dart';

/// Pump-posted defaults, one rate per grade.
///
/// These pre-fill a new fuel entry; they are never stored on a log. A log
/// keeps litres and total cost, and derives the unit price from those two.
class FuelPriceDefaults extends Equatable {
  const FuelPriceDefaults({this.octane92, this.octane95, this.diesel});

  static const empty = FuelPriceDefaults();

  final double? octane92;
  final double? octane95;
  final double? diesel;

  bool get isEmpty => octane92 == null && octane95 == null && diesel == null;

  double? priceOf(FuelType type) => switch (type) {
    FuelType.octane92 => octane92,
    FuelType.octane95 => octane95,
    FuelType.diesel => diesel,
  };

  FuelPriceDefaults withPrice(FuelType type, double? price) {
    final value = _positive(price);
    return switch (type) {
      FuelType.octane92 => FuelPriceDefaults(
        octane92: value,
        octane95: octane95,
        diesel: diesel,
      ),
      FuelType.octane95 => FuelPriceDefaults(
        octane92: octane92,
        octane95: value,
        diesel: diesel,
      ),
      FuelType.diesel => FuelPriceDefaults(
        octane92: octane92,
        octane95: octane95,
        diesel: value,
      ),
    };
  }

  Map<String, double> toJson() => {
    if (octane92 != null) FuelType.octane92.name: octane92!,
    if (octane95 != null) FuelType.octane95.name: octane95!,
    if (diesel != null) FuelType.diesel.name: diesel!,
  };

  factory FuelPriceDefaults.fromJson(Object? value) {
    if (value is! Map) return empty;
    return FuelPriceDefaults(
      octane92: _positive(value[FuelType.octane92.name]),
      octane95: _positive(value[FuelType.octane95.name]),
      diesel: _positive(value[FuelType.diesel.name]),
    );
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
  List<Object?> get props => [octane92, octane95, diesel];
}
