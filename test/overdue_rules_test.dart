import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/next_service_due.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/service_catalog.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/upcoming_service.dart';

void main() {
  group('overdue reads both limits', () {
    NextServiceDue dueWith({
      required int kmRemaining,
      required DateTime targetDate,
      required DueDriver driver,
    }) => NextServiceDue(
      milestone: ServiceCatalog.milestoneForPhase(1, targetOdometer: 10000),
      targetOdometer: 10000,
      kmRemaining: kmRemaining,
      dailyPace: 20,
      vehicleInitialOdometer: 0,
      targetDate: targetDate,
      dueDriver: driver,
    );

    test('a passed date is overdue even when distance is the driver', () {
      final due = dueWith(
        // Still 400 km to run, so the odometer says "coming up"...
        kmRemaining: 400,
        // ...but the calendar limit went by two months ago.
        targetDate: DateTime.now().subtract(const Duration(days: 60)),
        driver: DueDriver.distance,
      );

      expect(due.isOverdue, isTrue);
      expect(due.isDueSoon, isFalse);
    });

    test('a passed odometer target is overdue on its own', () {
      final due = dueWith(
        kmRemaining: -50,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        driver: DueDriver.time,
      );
      expect(due.isOverdue, isTrue);
    });

    test('both limits comfortable is neither overdue nor due soon', () {
      final due = dueWith(
        kmRemaining: 4000,
        targetDate: DateTime.now().add(const Duration(days: 120)),
        driver: DueDriver.distance,
      );
      expect(due.isOverdue, isFalse);
      expect(due.isDueSoon, isFalse);
    });

    test('an upcoming stop past its projected date is overdue', () {
      final service = UpcomingService(
        milestone: ServiceCatalog.milestoneForPhase(1, targetOdometer: 10000),
        kmRemaining: 700,
        isCompleted: false,
        estimatedDate: DateTime.now().subtract(const Duration(days: 5)),
        dueDriver: DueDriver.time,
      );

      expect(service.isOverdue, isTrue);
      // The distance is still positive — display code must read the sign of
      // `kmRemaining`, never infer "N km overdue" from `isOverdue`.
      expect(service.kmRemaining, greaterThan(0));
      expect(service.isDueSoon, isFalse);
    });

    test('a completed stop is never overdue', () {
      final service = UpcomingService(
        milestone: ServiceCatalog.milestoneForPhase(1, targetOdometer: 10000),
        kmRemaining: -3000,
        isCompleted: true,
        estimatedDate: DateTime.now().subtract(const Duration(days: 400)),
      );
      expect(service.isOverdue, isFalse);
    });
  });
}
