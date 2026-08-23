import 'consumable_part.dart';
import 'service_milestone.dart';

/// Brand-agnostic baseline roadmap. Every rule is derived from odometer
/// harmonics so it applies unchanged to any vehicle, and a user override of a
/// part lifespan never invalidates the schedule.
///
/// The catalogue only answers *what* a periodic stop covers, keyed by its
/// [phaseIndex] (0 = break-in check, 1, 2, 3 … = successive 10,000 km
/// intervals). It never answers *when* a stop is due — that is a function of
/// the vehicle's actual service history and belongs to `PredictServices`,
/// which computes each stop's real, drifting `targetOdometer` and passes it
/// in here.
class ServiceCatalog {
  const ServiceCatalog._();

  static const int firstCheckKm = 1000;
  static const int firstCheckMonths = 1;
  static const int intervalKm = 10000;
  static const int monthsPerInterval = 6;
  static const int plannedHorizonKm = 120000;

  static const String supplyCleaners = 'itemCleanerSupplies';

  /// The fixed-grid odometer for a phase — used only to decide which parts a
  /// stop covers (the harmonics below are all multiples of this nominal
  /// value), never to decide when the stop actually falls due.
  static int nominalOdometerFor(int phaseIndex) =>
      phaseIndex <= 0 ? firstCheckKm : phaseIndex * intervalKm;

  /// Best-effort phase for a record saved before phases were tracked
  /// explicitly. A `milestoneOdometer` that still lands exactly on the grid
  /// (as every one did before this change) identifies its phase unambiguously;
  /// anything off-grid — the whole point of the dynamic schedule — cannot be
  /// resolved this way and is treated as an ad-hoc record instead.
  static int? legacyPhaseFor(int? milestoneOdometer) {
    if (milestoneOdometer == null) return null;
    if (milestoneOdometer == firstCheckKm) return 0;
    if (milestoneOdometer > 0 && milestoneOdometer % intervalKm == 0) {
      return milestoneOdometer ~/ intervalKm;
    }
    return null;
  }

  /// Builds the stop for [phaseIndex], covering the parts/tier the nominal
  /// grid position implies, but stamped with the caller's dynamically
  /// computed [targetOdometer].
  static ServiceMilestone milestoneForPhase(
    int phaseIndex, {
    required int targetOdometer,
  }) {
    if (phaseIndex <= 0) return _firstCheck(targetOdometer);

    final nominalKm = nominalOdometerFor(phaseIndex);

    final replace = <ConsumablePart>{
      ConsumablePart.engineOil,
      ConsumablePart.oilFilter,
      ConsumablePart.drainPlugGasket,
    };
    final conditional = <ConsumablePart>{};
    final inspect = <String>{
      supplyCleaners,
      'checkTires',
      'checkSuspension',
      'checkTightening',
      'checkLights',
    };

    if (nominalKm % 20000 == 0) {
      replace.addAll([
        ConsumablePart.fuelFilter,
        ConsumablePart.airFilter,
        ConsumablePart.sparkPlugs,
      ]);
    }

    if (nominalKm % 40000 == 0) {
      replace.addAll([
        ConsumablePart.powerSteeringFluid,
        ConsumablePart.brakeFluid,
        ConsumablePart.coolant,
      ]);
      conditional.add(ConsumablePart.brakePads);
      inspect.addAll(['checkRearPads', 'checkCoolingCircuit', 'checkBattery']);
    }

    if (nominalKm % 60000 == 0) {
      replace.addAll([
        ConsumablePart.airFilter,
        ConsumablePart.sparkPlugs,
        ConsumablePart.transmissionOil,
        ConsumablePart.transmissionFilter,
      ]);
    }

    if (nominalKm % 100000 == 0) {
      replace.addAll([ConsumablePart.timingBelt, ConsumablePart.driveBelt]);
      inspect.add('checkCoolingCircuit');
    }

    if (nominalKm % 30000 == 0) {
      conditional.add(ConsumablePart.brakePads);
      inspect.add('checkRearPads');
    }

    final tier = switch (nominalKm) {
      _ when nominalKm % 100000 == 0 => ServiceTier.major,
      _ when nominalKm % 40000 == 0 => ServiceTier.major,
      _ when nominalKm % 60000 == 0 => ServiceTier.important,
      _ when nominalKm % 20000 == 0 => ServiceTier.important,
      _ => ServiceTier.minor,
    };

    return ServiceMilestone(
      phaseIndex: phaseIndex,
      targetOdometer: targetOdometer,
      tier: tier,
      replaceParts: List.unmodifiable(replace),
      conditionalParts: List.unmodifiable(conditional),
      inspectKeys: List.unmodifiable(inspect),
      recommendedMonths: phaseIndex * monthsPerInterval,
    );
  }

  /// The break-in check is a free safety scan. Oil and filter are offered as
  /// optional extras only — they are never billed into the estimate. It is
  /// not part of the interval chain, so it never drifts.
  static ServiceMilestone _firstCheck(int targetOdometer) => ServiceMilestone(
    phaseIndex: 0,
    targetOdometer: targetOdometer,
    tier: ServiceTier.firstCheck,
    replaceParts: const [],
    conditionalParts: List.unmodifiable([
      ConsumablePart.engineOil,
      ConsumablePart.oilFilter,
    ]),
    inspectKeys: List.unmodifiable([
      'checkFluidLevels',
      'checkTightening',
      'checkChassisScan',
      'checkTires',
      'checkLights',
      'checkLeaks',
    ]),
    recommendedMonths: firstCheckMonths,
    isComplimentary: true,
  );
}
