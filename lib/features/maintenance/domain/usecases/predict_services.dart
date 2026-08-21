import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/maintenance_record.dart';
import '../entities/next_service_due.dart';
import '../entities/service_catalog.dart';
import '../entities/service_milestone.dart';
import '../entities/upcoming_service.dart';

class PredictServices {
  const PredictServices();

  List<UpcomingService> call({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    double avgDailyKmFromFuel = 0,
    int aheadCount = 8,
  }) {
    final pace = dailyPace(
      vehicle: vehicle,
      avgDailyKmFromFuel: avgDailyKmFromFuel,
    );
    final closed = _closedTargets(records);
    final recordByTarget = _recordsByTarget(records);

    return ServiceCatalog.roadmap(vehicle.currentOdometer, aheadCount: aheadCount)
        .map((ms) => _position(ms, vehicle, pace, closed, recordByTarget))
        .toList(growable: false);
  }

  List<UpcomingService> upcoming({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    double avgDailyKmFromFuel = 0,
    int limit = 3,
  }) => call(
    vehicle: vehicle,
    records: records,
    avgDailyKmFromFuel: avgDailyKmFromFuel,
  ).where((s) => !s.isCompleted).take(limit).toList(growable: false);

  NextServiceDue? nextDue({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    double avgDailyKmFromFuel = 0,
  }) {
    final pace = dailyPace(
      vehicle: vehicle,
      avgDailyKmFromFuel: avgDailyKmFromFuel,
    );
    final last = lastPerformed(records, vehicle.id);
    final closed = _closedTargets(records);

    final anchorOdometer = last?.odometer ?? vehicle.initialOdometer;
    var target = ServiceCatalog.nextTargetAfter(anchorOdometer);
    while (target != null && closed.contains(target)) {
      target = ServiceCatalog.nextTargetAfter(target);
    }
    if (target == null) return null;

    final milestone = ServiceCatalog.milestoneAt(target);
    final kmRemaining = target - vehicle.currentOdometer;

    final distanceDate = pace > 0
        ? DateTime.now().add(
            Duration(days: (kmRemaining / pace).round().clamp(-36500, 36500)),
          )
        : null;

    final anchorDate = last?.date ?? vehicle.purchaseDate ?? vehicle.createdAt;
    final timeDate = _addMonths(
      anchorDate,
      last == null
          ? milestone.recommendedMonths
          : ServiceCatalog.monthsPerInterval,
    );

    final DateTime? targetDate;
    final DueDriver driver;
    if (distanceDate == null) {
      targetDate = timeDate;
      driver = DueDriver.time;
    } else if (timeDate.isBefore(distanceDate)) {
      targetDate = timeDate;
      driver = DueDriver.time;
    } else {
      targetDate = distanceDate;
      driver = DueDriver.distance;
    }

    return NextServiceDue(
      milestone: milestone,
      targetOdometer: target,
      kmRemaining: kmRemaining,
      dailyPace: pace,
      targetDate: targetDate,
      dueDriver: driver,
      lastService: last,
      monthsSinceLastService: last == null
          ? null
          : _monthsBetween(last.date, DateTime.now()),
    );
  }

  MaintenanceRecord? lastPerformed(
    List<MaintenanceRecord> records,
    String vehicleId,
  ) {
    MaintenanceRecord? latest;
    for (final r in records) {
      if (r.vehicleId != vehicleId) continue;
      if (latest == null || r.odometer > latest.odometer) latest = r;
    }
    return latest;
  }

  Set<int> _closedTargets(List<MaintenanceRecord> records) => {
    for (final r in records)
      if (r.milestoneOdometer != null) r.milestoneOdometer!,
  };

  Map<int, MaintenanceRecord> _recordsByTarget(
    List<MaintenanceRecord> records,
  ) => {
    for (final r in records)
      if (r.milestoneOdometer != null) r.milestoneOdometer!: r,
  };

  UpcomingService _position(
    ServiceMilestone ms,
    Vehicle vehicle,
    double pace,
    Set<int> closed,
    Map<int, MaintenanceRecord> recordByTarget,
  ) {
    final kmRemaining = ms.targetOdometer - vehicle.currentOdometer;
    final completed = closed.contains(ms.targetOdometer);
    return UpcomingService(
      milestone: ms,
      kmRemaining: kmRemaining,
      isCompleted: completed,
      completedRecord: recordByTarget[ms.targetOdometer],
      estimatedDate: completed || pace <= 0
          ? null
          : DateTime.now().add(
              Duration(days: (kmRemaining / pace).round().clamp(0, 36500)),
            ),
    );
  }

  double dailyPace({
    required Vehicle vehicle,
    double avgDailyKmFromFuel = 0,
  }) {
    if (avgDailyKmFromFuel > 0) return avgDailyKmFromFuel;

    final since = (vehicle.odometerUpdatedAt ?? DateTime.now())
        .difference(vehicle.createdAt)
        .inDays;
    final distance = vehicle.trackedDistanceKm;
    if (since <= 0 || distance <= 0) return 0;
    return distance / since;
  }

  double monthlyPace({
    required Vehicle vehicle,
    double avgDailyKmFromFuel = 0,
  }) =>
      dailyPace(vehicle: vehicle, avgDailyKmFromFuel: avgDailyKmFromFuel) *
      30.44;

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    return DateTime(d.year + total ~/ 12, total % 12 + 1, d.day);
  }
}
