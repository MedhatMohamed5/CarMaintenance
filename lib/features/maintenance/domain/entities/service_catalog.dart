import 'consumable_part.dart';
import 'service_milestone.dart';

class ServiceCatalog {
  const ServiceCatalog._();

  static const int firstCheckKm = 1000;
  static const int firstCheckMonths = 1;
  static const int intervalKm = 10000;
  static const int monthsPerInterval = 6;
  static const int plannedHorizonKm = 100000;

  static ServiceMilestone milestoneAt(int targetOdometer) {
    if (targetOdometer <= firstCheckKm) return _firstCheck();

    final km = targetOdometer;
    final replace = <ConsumablePart>[
      ConsumablePart.engineOil,
      ConsumablePart.oilFilter,
    ];
    final conditional = <ConsumablePart>[];
    final inspect = <String>[
      'checkTires',
      'checkSuspension',
      'checkTightening',
      'checkLights',
    ];

    if (km % 20000 == 0) replace.add(ConsumablePart.airFilter);
    if (km % 40000 == 0) replace.add(ConsumablePart.cabinFilter);

    if (km % 30000 == 0) {
      conditional.add(ConsumablePart.brakePads);
      inspect.addAll(['checkRearPads', 'checkCoolingCircuit']);
    }

    if (km % 40000 == 0) {
      replace.addAll([
        ConsumablePart.sparkPlugs,
        ConsumablePart.coolant,
        ConsumablePart.powerSteeringFluid,
        ConsumablePart.brakeFluid,
      ]);
      inspect.add('checkBattery');
    }

    if (km % 60000 == 0) replace.add(ConsumablePart.transmissionOil);

    final tier = switch (km) {
      _ when km % 40000 == 0 => ServiceTier.major,
      _ when km % 30000 == 0 => ServiceTier.important,
      _ => ServiceTier.minor,
    };

    return ServiceMilestone(
      targetOdometer: km,
      tier: tier,
      replaceParts: List.unmodifiable(replace),
      conditionalParts: List.unmodifiable(conditional),
      inspectKeys: List.unmodifiable(inspect),
      recommendedMonths: (km ~/ intervalKm) * monthsPerInterval,
    );
  }

  static ServiceMilestone _firstCheck() => ServiceMilestone(
    targetOdometer: firstCheckKm,
    tier: ServiceTier.firstCheck,
    replaceParts: List.unmodifiable([
      ConsumablePart.engineOil,
      ConsumablePart.oilFilter,
    ]),
    conditionalParts: const [],
    inspectKeys: List.unmodifiable([
      'checkTightening',
      'checkTires',
      'checkLights',
      'checkCoolingCircuit',
    ]),
    recommendedMonths: firstCheckMonths,
  );

  static List<int> plannedTargets() => [
    firstCheckKm,
    for (var km = intervalKm; km <= plannedHorizonKm; km += intervalKm) km,
  ];

  static List<ServiceMilestone> baseline() =>
      plannedTargets().map(milestoneAt).toList(growable: false);

  static int? nextTargetAfter(int odometer) {
    if (odometer < firstCheckKm) return firstCheckKm;
    return ((odometer ~/ intervalKm) + 1) * intervalKm;
  }

  static List<ServiceMilestone> upcomingFrom(int odometer, {int count = 6}) {
    final targets = <int>[];
    var cursor = odometer;
    while (targets.length < count) {
      final next = nextTargetAfter(cursor);
      if (next == null) break;
      targets.add(next);
      cursor = next;
    }
    return targets.map(milestoneAt).toList(growable: false);
  }

  static List<ServiceMilestone> roadmap(int odometer, {int aheadCount = 8}) {
    final planned = plannedTargets();
    final horizon = odometer + aheadCount * intervalKm;
    final targets = <int>{
      ...planned.where((km) => km <= horizon),
      ...upcomingFrom(odometer, count: aheadCount).map((m) => m.targetOdometer),
    }.toList()..sort();

    return targets.map(milestoneAt).toList(growable: false);
  }
}
