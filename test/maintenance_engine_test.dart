import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/consumable_part.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/maintenance_record.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/part_health.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/part_replacement.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/service_catalog.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/service_milestone.dart';
import 'package:vehicle_care/features/maintenance/domain/usecases/calculate_parts_health.dart';
import 'package:vehicle_care/features/maintenance/domain/usecases/predict_services.dart';
import 'package:vehicle_care/features/vehicles/domain/entities/vehicle.dart';

Vehicle vehicle({
  int initial = 0,
  int current = 10000,
  DateTime? createdAt,
  DateTime? odometerUpdatedAt,
  Map<String, int> overrides = const {},
}) => Vehicle(
  id: 'v1',
  make: 'Toyota',
  model: 'Corolla',
  year: 2022,
  initialOdometer: initial,
  currentOdometer: current,
  createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 100)),
  odometerUpdatedAt: odometerUpdatedAt ?? DateTime.now(),
  partLifespanOverridesKm: overrides,
);

void main() {
  group('ServiceCatalog', () {
    test('classifies tiers by odometer harmonics', () {
      expect(ServiceCatalog.milestoneAt(10000).tier, ServiceTier.minor);
      expect(ServiceCatalog.milestoneAt(30000).tier, ServiceTier.important);
      expect(ServiceCatalog.milestoneAt(40000).tier, ServiceTier.major);
      // 120k is divisible by both 30k and 40k — major wins.
      expect(ServiceCatalog.milestoneAt(120000).tier, ServiceTier.major);
    });

    test('every service changes oil and oil filter', () {
      for (final km in [10000, 20000, 30000, 40000, 250000]) {
        final ms = ServiceCatalog.milestoneAt(km);
        expect(ms.replaceParts, contains(ConsumablePart.engineOil));
        expect(ms.replaceParts, contains(ConsumablePart.oilFilter));
      }
    });

    test('major service folds in the heavy items', () {
      final ms = ServiceCatalog.milestoneAt(40000);
      expect(ms.replaceParts, contains(ConsumablePart.sparkPlugs));
      expect(ms.replaceParts, contains(ConsumablePart.coolant));
      expect(ms.replaceParts, contains(ConsumablePart.powerSteeringFluid));
      expect(ms.recommendedMonths, 24);
    });

    test('transmission oil only appears on the 60k harmonic', () {
      expect(
        ServiceCatalog.milestoneAt(60000).replaceParts,
        contains(ConsumablePart.transmissionOil),
      );
      expect(
        ServiceCatalog.milestoneAt(50000).replaceParts,
        isNot(contains(ConsumablePart.transmissionOil)),
      );
    });

    test('upcomingFrom starts strictly after the current reading', () {
      final next = ServiceCatalog.upcomingFrom(10000, count: 2);
      expect(next.first.targetOdometer, 20000);
      expect(next.last.targetOdometer, 30000);
    });
  });

  group('CalculatePartsHealth', () {
    const calc = CalculatePartsHealth();

    test('measures from the vehicle baseline when never replaced', () {
      final health = calc(
        vehicle: vehicle(initial: 0, current: 5000),
        replacements: const [],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.consumedKm, 5000);
      expect(health.single.remainingKm, 5000);
      expect(health.single.fractionRemaining, closeTo(0.5, 1e-9));
      expect(health.single.status, HealthStatus.healthy);
    });

    test('a replacement resets the baseline', () {
      final health = calc(
        vehicle: vehicle(initial: 0, current: 15000),
        replacements: [
          PartReplacement(
            id: 'r1',
            vehicleId: 'v1',
            part: ConsumablePart.engineOil,
            odometer: 12000,
            date: DateTime.now(),
          ),
        ],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.consumedKm, 3000);
      expect(health.single.dueAtOdometer, 22000);
    });

    test('uses the latest replacement when several exist', () {
      final health = calc(
        vehicle: vehicle(initial: 0, current: 30000),
        replacements: [
          PartReplacement(
            id: 'r1',
            vehicleId: 'v1',
            part: ConsumablePart.engineOil,
            odometer: 12000,
            date: DateTime.now(),
          ),
          PartReplacement(
            id: 'r2',
            vehicleId: 'v1',
            part: ConsumablePart.engineOil,
            odometer: 25000,
            date: DateTime.now(),
          ),
        ],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.lastServiceOdometer, 25000);
      expect(health.single.consumedKm, 5000);
    });

    test('never reports a negative bar when overdue', () {
      final health = calc(
        vehicle: vehicle(initial: 0, current: 40000),
        replacements: const [],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.fractionRemaining, 0);
      expect(health.single.remainingKm, 0);
      expect(health.single.status, HealthStatus.overdue);
    });

    test('honours a per-vehicle lifespan override', () {
      final health = calc(
        vehicle: vehicle(
          initial: 0,
          current: 5000,
          overrides: {ConsumablePart.engineOil.id: 5000},
        ),
        replacements: const [],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.lifespanKm, 5000);
      expect(health.single.isOverdue, isTrue);
    });

    test('ignores replacements belonging to another vehicle', () {
      final health = calc(
        vehicle: vehicle(initial: 0, current: 5000),
        replacements: [
          PartReplacement(
            id: 'r1',
            vehicleId: 'other',
            part: ConsumablePart.engineOil,
            odometer: 4000,
            date: DateTime.now(),
          ),
        ],
        parts: [ConsumablePart.engineOil],
      );

      expect(health.single.lastServiceOdometer, 0);
    });

    test('the calendar limit can bite before the distance limit', () {
      // Coolant is rated 40,000 km but only 24 months. A car that barely moves
      // still needs it changed.
      final health = calc(
        vehicle: vehicle(
          initial: 0,
          current: 3000,
          createdAt: DateTime.now().subtract(const Duration(days: 700)),
        ),
        replacements: const [],
        parts: [ConsumablePart.coolant],
      );

      expect(health.single.limitedByTime, isTrue);
      expect(health.single.fractionRemaining, lessThan(0.2));
    });
  });

  group('PredictServices', () {
    const predict = PredictServices();

    test('marks a passed-but-unlogged milestone as overdue', () {
      final services = predict(
        vehicle: vehicle(initial: 0, current: 21000),
        records: const [],
      );
      final twenty = services.firstWhere((s) => s.targetOdometer == 20000);
      expect(twenty.isOverdue, isTrue);
      expect(twenty.kmRemaining, -1000);
    });

    test('a logged milestone is closed, not overdue', () {
      final services = predict(
        vehicle: vehicle(initial: 0, current: 21000),
        records: [
          MaintenanceRecord(
            id: 'm1',
            vehicleId: 'v1',
            date: DateTime.now(),
            odometer: 20050,
            title: 'Service',
            tier: ServiceTier.minor,
            milestoneOdometer: 20000,
          ),
        ],
      );
      final twenty = services.firstWhere((s) => s.targetOdometer == 20000);
      expect(twenty.isCompleted, isTrue);
      expect(twenty.isOverdue, isFalse);
    });

    test('projects a date from the fuel-measured pace', () {
      final services = predict(
        vehicle: vehicle(initial: 0, current: 19000),
        records: const [],
        avgDailyKmFromFuel: 50,
      );
      final twenty = services.firstWhere((s) => s.targetOdometer == 20000);
      // 1000 km left at 50 km/day = 20 days out.
      final days = twenty.estimatedDate!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(19, 20));
    });

    test('refuses to invent a date with no pace evidence', () {
      final now = DateTime.now();
      final services = predict(
        vehicle: vehicle(
          initial: 5000,
          current: 5000,
          createdAt: now,
          odometerUpdatedAt: now,
        ),
        records: const [],
      );
      expect(services.every((s) => s.estimatedDate == null), isTrue);
    });

    test('falls back to the odometer trail when fuel data is absent', () {
      final pace = predict.dailyPace(
        vehicle: vehicle(
          initial: 0,
          current: 2000,
          createdAt: DateTime.now().subtract(const Duration(days: 40)),
          odometerUpdatedAt: DateTime.now(),
        ),
      );
      expect(pace, closeTo(50, 2));
    });

    test('flags an imminent service as due soon', () {
      final services = predict(
        vehicle: vehicle(initial: 0, current: 19500),
        records: const [],
      );
      final twenty = services.firstWhere((s) => s.targetOdometer == 20000);
      expect(twenty.isDueSoon, isTrue);
      expect(twenty.isOverdue, isFalse);
    });
  });
}
