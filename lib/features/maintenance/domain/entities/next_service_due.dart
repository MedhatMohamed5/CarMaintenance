import 'package:equatable/equatable.dart';

import '../../../../core/constants/service_thresholds.dart';
import 'maintenance_record.dart';
import 'service_catalog.dart';
import 'service_milestone.dart';

enum DueDriver { distance, time }

class NextServiceDue extends Equatable {
  const NextServiceDue({
    required this.milestone,
    required this.targetOdometer,
    required this.kmRemaining,
    required this.dailyPace,
    required this.vehicleInitialOdometer,
    this.targetDate,
    this.dueDriver = DueDriver.distance,
    this.lastService,
    this.monthsSinceLastService,
  });

  final ServiceMilestone milestone;
  final int targetOdometer;
  final int kmRemaining;
  final double dailyPace;
  final DateTime? targetDate;
  final DueDriver dueDriver;
  final MaintenanceRecord? lastService;
  final int? monthsSinceLastService;

  /// Floor for [intervalStartOdometer] when no service has ever been logged —
  /// the vehicle's own starting reading, never zero.
  final int vehicleInitialOdometer;

  ServiceTier get tier => milestone.tier;

  /// Odometer the current interval is measured from: the last completed
  /// service if one exists, otherwise the vehicle's own starting reading.
  int get intervalStartOdometer =>
      lastService?.odometer ?? vehicleInitialOdometer;

  /// Recovered from figures already carried here rather than duplicating a
  /// third field: `targetOdometer - kmRemaining` is exactly the vehicle's
  /// current reading.
  int get currentOdometer => targetOdometer - kmRemaining;

  /// Full distance this interval spans. A back-dated log placed at or past
  /// its own target — or a used vehicle added past the target — would make
  /// this non-positive; the catalogue's base interval is the safe fallback,
  /// never zero or negative.
  int get intervalSpanKm {
    final span = targetOdometer - intervalStartOdometer;
    return span <= 0 ? ServiceCatalog.intervalKm : span;
  }

  /// Distance already covered within the current interval, floored at zero
  /// so a stale or back-dated reading never reads as negative progress.
  int get travelledKm =>
      (currentOdometer - intervalStartOdometer).clamp(0, 1 << 31);

  /// Distance traveled since the last service relative to the full service
  /// interval distance, strictly clamped to 0..1 — safe to hand straight to
  /// a progress bar even when the service is overdue and [travelledKm]
  /// overruns [intervalSpanKm].
  double get progress =>
      (travelledKm / intervalSpanKm).clamp(0.0, 1.0).toDouble();

  bool get isOverdue => kmRemaining < 0 || _timeOverdue;

  bool get isDueSoon =>
      !isOverdue &&
      (kmRemaining <= ServiceThresholds.dueSoonKm ||
          _withinDays(ServiceThresholds.dueSoonDays));

  bool get _timeOverdue {
    final date = targetDate;
    return dueDriver == DueDriver.time &&
        date != null &&
        date.isBefore(DateTime.now());
  }

  bool _withinDays(int days) {
    final date = targetDate;
    if (date == null) return false;
    return date.difference(DateTime.now()).inDays <= days;
  }

  int get daysRemaining {
    final date = targetDate;
    if (date == null) return 0;
    return date.difference(DateTime.now()).inDays;
  }

  @override
  List<Object?> get props => [
    milestone,
    targetOdometer,
    kmRemaining,
    dailyPace,
    vehicleInitialOdometer,
    targetDate,
    dueDriver,
    lastService,
    monthsSinceLastService,
  ];
}
