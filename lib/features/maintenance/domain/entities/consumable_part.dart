/// Catalogue of wearing parts the app tracks.
///
/// Lifespans are conservative manufacturer-typical figures and act only as the
/// default; a vehicle can override any of them via
/// `Vehicle.partLifespanOverridesKm`, and the user resets a part by logging a
/// replacement.
enum ConsumablePart {
  engineOil(
    l10nKey: 'partEngineOil',
    defaultLifespanKm: 10000,
    defaultLifespanMonths: 12,
    colorValue: 0xFF34D399,
    iconKey: 'oil',
  ),
  oilFilter(
    l10nKey: 'partOilFilter',
    defaultLifespanKm: 10000,
    defaultLifespanMonths: 12,
    colorValue: 0xFF2DD4BF,
    iconKey: 'filter',
  ),
  airFilter(
    l10nKey: 'partAirFilter',
    defaultLifespanKm: 20000,
    defaultLifespanMonths: 24,
    colorValue: 0xFF22D3EE,
    iconKey: 'air',
  ),
  cabinFilter(
    l10nKey: 'partCabinFilter',
    defaultLifespanKm: 20000,
    defaultLifespanMonths: 24,
    colorValue: 0xFF818CF8,
    iconKey: 'air',
  ),
  brakePads(
    l10nKey: 'partBrakePads',
    defaultLifespanKm: 30000,
    defaultLifespanMonths: 36,
    colorValue: 0xFFF59E0B,
    iconKey: 'brake',
  ),
  brakeFluid(
    l10nKey: 'partBrakeFluid',
    defaultLifespanKm: 40000,
    defaultLifespanMonths: 24,
    colorValue: 0xFFFB923C,
    iconKey: 'fluid',
  ),
  tires(
    l10nKey: 'partTires',
    defaultLifespanKm: 50000,
    defaultLifespanMonths: 48,
    colorValue: 0xFF38BDF8,
    iconKey: 'tire',
  ),
  transmissionOil(
    l10nKey: 'partTransmissionOil',
    defaultLifespanKm: 60000,
    defaultLifespanMonths: 60,
    colorValue: 0xFF34D399,
    iconKey: 'oil',
  ),
  powerSteeringFluid(
    l10nKey: 'partPowerSteering',
    defaultLifespanKm: 40000,
    defaultLifespanMonths: 48,
    colorValue: 0xFFF472B6,
    iconKey: 'fluid',
  ),
  coolant(
    l10nKey: 'partCoolant',
    defaultLifespanKm: 40000,
    defaultLifespanMonths: 24,
    colorValue: 0xFF3B82F6,
    iconKey: 'coolant',
  ),
  sparkPlugs(
    l10nKey: 'partSparkPlugs',
    defaultLifespanKm: 40000,
    defaultLifespanMonths: 48,
    colorValue: 0xFFA78BFA,
    iconKey: 'spark',
  ),
  battery(
    l10nKey: 'partBattery',
    defaultLifespanKm: 60000,
    defaultLifespanMonths: 36,
    colorValue: 0xFFFACC15,
    iconKey: 'battery',
  ),
  fuelFilter(
    l10nKey: 'partFuelFilter',
    defaultLifespanKm: 20000,
    defaultLifespanMonths: 24,
    colorValue: 0xFF2DD4BF,
    iconKey: 'filter',
  ),
  drainPlugGasket(
    l10nKey: 'partDrainPlugGasket',
    defaultLifespanKm: 10000,
    defaultLifespanMonths: 12,
    colorValue: 0xFF9AA3B2,
    iconKey: 'filter',
  ),
  transmissionFilter(
    l10nKey: 'partTransmissionFilter',
    defaultLifespanKm: 60000,
    defaultLifespanMonths: 60,
    colorValue: 0xFF34D399,
    iconKey: 'filter',
  ),
  timingBelt(
    l10nKey: 'partTimingBelt',
    defaultLifespanKm: 100000,
    defaultLifespanMonths: 120,
    colorValue: 0xFFF87171,
    iconKey: 'spark',
  ),
  driveBelt(
    l10nKey: 'partDriveBelt',
    defaultLifespanKm: 100000,
    defaultLifespanMonths: 120,
    colorValue: 0xFFFB923C,
    iconKey: 'spark',
  );

  const ConsumablePart({
    required this.l10nKey,
    required this.defaultLifespanKm,
    required this.defaultLifespanMonths,
    required this.colorValue,
    required this.iconKey,
  });

  final String l10nKey;
  final int defaultLifespanKm;

  /// Some fluids age by time as much as by distance (brake fluid, coolant).
  /// The health calculator takes whichever limit is reached first.
  final int defaultLifespanMonths;

  final int colorValue;
  final String iconKey;

  String get id => name;

  /// The six the dashboard visualiser highlights, in the order the user asked
  /// for them.
  static const List<ConsumablePart> dashboardOrder = [
    tires,
    brakePads,
    engineOil,
    transmissionOil,
    powerSteeringFluid,
    coolant,
  ];

  static ConsumablePart fromId(String? id) => ConsumablePart.values.firstWhere(
    (p) => p.name == id,
    orElse: () => ConsumablePart.engineOil,
  );
}
