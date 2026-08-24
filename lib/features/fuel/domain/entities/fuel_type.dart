/// Fuel grades the app can compare. Adding a grade is one entry here plus one
/// localised label — nothing else in the engine needs to change.
enum FuelType {
  octane80('octane80'),
  octane92('octane92'),
  octane95('octane95'),
  diesel('diesel'),
  naturalGas('naturalGas');

  const FuelType(this.l10nKey);

  /// Key into the string tables, so grades stay translatable.
  final String l10nKey;

  /// CNG is metered in cubic metres; liquid grades stay in litres. Quantity
  /// is still stored on [FuelLog.liters] so historical receipts do not move.
  bool get isGaseous => this == FuelType.naturalGas;

  String get volumeUnitKey => isGaseous ? 'cubicMeter' : 'liter';

  String get priceLabelKey =>
      isGaseous ? 'pricePerCubicMeter' : 'pricePerLiter';

  String get amountLabelKey => isGaseous ? 'fuelAmountGas' : 'fuelAmount';

  static FuelType fromName(String? name) {
    if (name == null || name.isEmpty) return FuelType.octane92;
    for (final type in FuelType.values) {
      if (type.name == name) return type;
    }
    return switch (name.toLowerCase()) {
      'cng' || 'natural_gas' || 'naturalgas' => FuelType.naturalGas,
      'octane_80' || '80' => FuelType.octane80,
      _ => FuelType.octane92,
    };
  }
}
