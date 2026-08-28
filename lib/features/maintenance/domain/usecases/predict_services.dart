import '../../../../core/constants/service_thresholds.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/maintenance_record.dart';
import '../entities/next_service_due.dart';
import '../entities/service_catalog.dart';
import '../entities/service_milestone.dart';
import '../entities/upcoming_service.dart';
import '../../../fuel/domain/fuel_math.dart';

/// Computes the periodic-service roadmap as a chain of *relative* intervals,
/// not a fixed 10k/20k/30k grid.
///
/// Core formula, applied phase by phase in order:
///
///   next target = last completed phase's actual odometer + interval distance
///
/// A service finished at 9,500 km instead of the nominal 10,000 km target
/// shifts every stop after it by the same 500 km — the 20,000 km stop becomes
/// due at 19,500 km, the 30,000 km stop at 29,500 km, and so on — until a
/// later phase closes off-grid again and re-anchors the chain from there. A
/// phase with no completed history of its own, directly or through an
/// earlier phase in the chain, falls back to one interval past the vehicle's
/// own starting reading — the nominal base milestone
/// (`phaseIndex * ServiceCatalog.intervalKm`) for a new vehicle added at 0,
/// and one interval past wherever a used vehicle actually joined otherwise.
class PredictServices {
  const PredictServices();

  /// [pace] and [phaseRecords] are the two things every entry point here
  /// derives from the same inputs. A caller that already holds them — the
  /// provider layer memoises both — passes them in rather than paying for them
  /// again; omit them and they are computed exactly as before.
  List<UpcomingService> call({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    double avgDailyKmFromFuel = 0,
    int aheadCount = 8,
    double? pace,
    Map<int, MaintenanceRecord>? phaseRecords,
  }) {
    final resolvedPace =
        pace ??
        dailyPace(vehicle: vehicle, avgDailyKmFromFuel: avgDailyKmFromFuel);
    final recordByPhase = phaseRecords ?? recordsByPhase(records);

    // Always cover the full baseline horizon (so a fresh vehicle sees its
    // whole plan), extended further once real history runs past it.
    final basePhaseCount =
        ServiceCatalog.plannedHorizonKm ~/ ServiceCatalog.intervalKm;
    final completedPeriodic = recordByPhase.keys.where((p) => p > 0).length;
    final phaseCount = completedPeriodic + aheadCount > basePhaseCount
        ? completedPeriodic + aheadCount
        : basePhaseCount;

    final vehicleStartDate = vehicle.purchaseDate ?? vehicle.createdAt;
    final chain = _buildChain(
      recordByPhase: recordByPhase,
      phaseCount: phaseCount,
      vehicleInitialOdometer: vehicle.initialOdometer,
      vehicleStartDate: vehicleStartDate,
    );

    final firstCheckMilestone = ServiceCatalog.milestoneForPhase(
      0,
      targetOdometer: ServiceCatalog.firstCheckKm,
    );

    return [
      _position(
        milestone: firstCheckMilestone,
        vehicle: vehicle,
        pace: resolvedPace,
        timeTarget: _addMonths(
          vehicleStartDate,
          firstCheckMilestone.recommendedMonths,
        ),
        record: recordByPhase[0],
      ),
      for (final slot in chain)
        _position(
          milestone: ServiceCatalog.milestoneForPhase(
            slot.phase,
            targetOdometer: slot.targetOdometer,
          ),
          vehicle: vehicle,
          pace: resolvedPace,
          timeTarget: slot.timeTarget!,
          record: slot.record,
        ),
    ];
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

  /// [pace], [phaseRecords] and [lastService] are optional pre-computed
  /// inputs; see [call].
  NextServiceDue? nextDue({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    double avgDailyKmFromFuel = 0,
    double? pace,
    Map<int, MaintenanceRecord>? phaseRecords,
    MaintenanceRecord? lastService,
  }) {
    final resolvedPace =
        pace ??
        dailyPace(vehicle: vehicle, avgDailyKmFromFuel: avgDailyKmFromFuel);
    final last = lastService ?? lastPerformed(records, vehicle.id);
    final recordByPhase = phaseRecords ?? recordsByPhase(records);
    final slot = _firstOpenSlot(recordByPhase, vehicle.initialOdometer);

    final milestone = ServiceCatalog.milestoneForPhase(
      slot.phase,
      targetOdometer: slot.targetOdometer,
    );
    final kmRemaining = slot.targetOdometer - vehicle.currentOdometer;

    final distanceDate = resolvedPace > 0
        ? DateTime.now().add(
            Duration(
              days: (kmRemaining / resolvedPace).round().clamp(
                -ProjectionLimits.horizonDays,
                ProjectionLimits.horizonDays,
              ),
            ),
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
      targetOdometer: slot.targetOdometer,
      kmRemaining: kmRemaining,
      dailyPace: resolvedPace,
      vehicleInitialOdometer: vehicle.initialOdometer,
      targetDate: targetDate,
      dueDriver: driver,
      lastService: last,
      monthsSinceLastService: last == null
          ? null
          : _monthsBetween(last.date, DateTime.now()),
    );
  }

  /// The nearest pending or upcoming stop of the same service [tier], so a
  /// manually logged entry can close it automatically — the auto-completion
  /// counterpart of tapping "Mark done" from the schedule, using the manual
  /// entry's own date and odometer as the completion reading.
  UpcomingService? matchOpenMilestone({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    required ServiceTier tier,
    double avgDailyKmFromFuel = 0,
  }) {
    for (final service in call(
      vehicle: vehicle,
      records: records,
      avgDailyKmFromFuel: avgDailyKmFromFuel,
    )) {
      if (service.isCompleted) continue;
      if (service.tier != tier) continue;
      return service;
    }
    return null;
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

  /// Maps each closed phase to the record that closes it, newest first on a
  /// tie. Legacy records without an explicit [MaintenanceRecord.milestonePhase]
  /// are resolved through [MaintenanceRecord.resolvedMilestonePhase].
  Map<int, MaintenanceRecord> recordsByPhase(List<MaintenanceRecord> records) {
    final map = <int, MaintenanceRecord>{};
    for (final r in records) {
      final phase = r.resolvedMilestonePhase;
      if (phase == null) continue;
      final existing = map[phase];
      if (existing == null || _isNewer(r, existing)) map[phase] = r;
    }
    return map;
  }

  static bool _isNewer(MaintenanceRecord a, MaintenanceRecord b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate > 0;
    return a.odometer > b.odometer;
  }

  /// Walks phases 1..[phaseCount] in order, carrying the actual odometer of
  /// the last *closed* phase forward as the anchor for the next one. Seeded
  /// with [vehicleInitialOdometer] rather than the nominal grid, so a used
  /// vehicle added at 45,000 km with no service history yet projects its
  /// first stop at 55,000 km — one interval past where it actually joined —
  /// instead of resetting to a stop already 35,000 km behind it. A new
  /// vehicle (`initialOdometer == 0`) seeds to exactly the same nominal grid
  /// this has always described. An open (not yet completed) phase still
  /// advances the anchor by its own projected target, so the roadmap ahead
  /// of it stays evenly spaced by one interval.
  List<_PhaseSlot> _buildChain({
    required Map<int, MaintenanceRecord> recordByPhase,
    required int phaseCount,
    required int vehicleInitialOdometer,
    required DateTime vehicleStartDate,
  }) {
    final slots = <_PhaseSlot>[];
    var anchorOdometer = vehicleInitialOdometer < 0
        ? 0
        : vehicleInitialOdometer;
    var anchorDate = vehicleStartDate;

    for (var phase = 1; phase <= phaseCount; phase++) {
      final target = anchorOdometer + ServiceCatalog.intervalKm;
      final timeTarget = _addMonths(
        anchorDate,
        ServiceCatalog.monthsPerInterval,
      );
      final record = recordByPhase[phase];
      slots.add(
        _PhaseSlot(
          phase: phase,
          targetOdometer: target,
          timeTarget: timeTarget,
          record: record,
        ),
      );
      anchorOdometer = record?.odometer ?? target;
      anchorDate = record?.date ?? timeTarget;
    }

    return slots;
  }

  /// The next stop that has not been closed yet, walking the same chain as
  /// [_buildChain] but stopping at the first gap. The break-in check is only
  /// a candidate while [vehicleInitialOdometer] is still short of it; a used
  /// vehicle added well past 1,000 km never had a break-in check to give, so
  /// it must not be forced into being "next up" forever.
  _PhaseSlot _firstOpenSlot(
    Map<int, MaintenanceRecord> recordByPhase,
    int vehicleInitialOdometer,
  ) {
    if (recordByPhase[0] == null &&
        vehicleInitialOdometer < ServiceCatalog.firstCheckKm) {
      return _PhaseSlot(
        phase: 0,
        targetOdometer: ServiceCatalog.firstCheckKm,
        record: null,
      );
    }

    var anchorOdometer = vehicleInitialOdometer < 0
        ? 0
        : vehicleInitialOdometer;
    var phase = 1;
    while (true) {
      final target = anchorOdometer + ServiceCatalog.intervalKm;
      final record = recordByPhase[phase];
      if (record == null) {
        return _PhaseSlot(phase: phase, targetOdometer: target, record: null);
      }
      anchorOdometer = record.odometer;
      phase++;
    }
  }

  /// Mirrors [nextDue]'s own rule: a stop is due at whichever comes first,
  /// the driver's measured pace or the milestone's calendar equivalent —
  /// never distance alone.
  UpcomingService _position({
    required ServiceMilestone milestone,
    required Vehicle vehicle,
    required double pace,
    required DateTime timeTarget,
    MaintenanceRecord? record,
  }) {
    final completed = record != null;
    final kmRemaining = milestone.targetOdometer - vehicle.currentOdometer;
    DateTime? estimatedDate;
    DueDriver? dueDriver;
    if (!completed) {
      final distanceDate = pace > 0
          ? DateTime.now().add(
              Duration(
                days: (kmRemaining / pace).round().clamp(
                  0,
                  ProjectionLimits.horizonDays,
                ),
              ),
            )
          : null;
      if (distanceDate == null || timeTarget.isBefore(distanceDate)) {
        estimatedDate = timeTarget;
        dueDriver = DueDriver.time;
      } else {
        estimatedDate = distanceDate;
        dueDriver = DueDriver.distance;
      }
    }
    return UpcomingService(
      milestone: milestone,
      kmRemaining: kmRemaining,
      isCompleted: completed,
      completedRecord: record,
      estimatedDate: estimatedDate,
      dueDriver: dueDriver,
    );
  }

  double dailyPace({required Vehicle vehicle, double avgDailyKmFromFuel = 0}) {
    if (avgDailyKmFromFuel > 0) return avgDailyKmFromFuel;

    // Same km-per-day formula the fuel engine uses, so a pace derived from the
    // odometer trail and one derived from fill history are computed identically.
    return FuelMath.kmPerDay(
      distanceKm: vehicle.trackedDistanceKm,
      days: (vehicle.odometerUpdatedAt ?? DateTime.now())
          .difference(vehicle.createdAt)
          .inDays,
    );
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

/// One phase's position in the chain before it is dressed up as a milestone:
/// its target odometer and, if closed, the record that closed it.
class _PhaseSlot {
  const _PhaseSlot({
    required this.phase,
    required this.targetOdometer,
    this.timeTarget,
    this.record,
  });

  final int phase;
  final int targetOdometer;

  /// Set only by [PredictServices._buildChain] — [PredictServices._firstOpenSlot]
  /// has no use for it, since [PredictServices.nextDue] derives its own
  /// calendar target directly.
  final DateTime? timeTarget;
  final MaintenanceRecord? record;
}
