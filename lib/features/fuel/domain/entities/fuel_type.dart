/// Fuel grades the app can compare. Adding a grade is one entry here plus one
/// localised label — nothing else in the engine needs to change.
enum FuelType {
  octane92('octane92'),
  octane95('octane95'),
  diesel('diesel');

  const FuelType(this.l10nKey);

  /// Key into the string tables, so grades stay translatable.
  final String l10nKey;

  static FuelType fromName(String? name) => FuelType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => FuelType.octane92,
  );
}
