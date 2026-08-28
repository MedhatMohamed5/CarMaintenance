import 'package:equatable/equatable.dart';

import '../../../../core/constants/service_thresholds.dart';
import 'maintenance_record.dart';
import 'service_milestone.dart';

/// A milestone positioned against a specific vehicle: how far away it is, when
/// it is expected, and whether it has already been closed.
class UpcomingService extends Equatable {
  const UpcomingService({
    required this.milestone,
    required this.kmRemaining,
    required this.isCompleted,
    this.estimatedDate,
    this.completedRecord,
  });

  final ServiceMilestone milestone;

  /// Negative when the target odometer has already been passed without the
  /// service being logged — that is what makes it overdue.
  final int kmRemaining;

  final bool isCompleted;

  /// Projected from the driver's own daily average; null when there is not yet
  /// enough history to project honestly.
  final DateTime? estimatedDate;

  final MaintenanceRecord? completedRecord;

  bool get isOverdue => !isCompleted && kmRemaining < 0;

  /// Alert threshold: within 500 km, or within 14 days at the driver's own
  /// measured pace.
  bool get isDueSoon {
    if (isCompleted || kmRemaining < 0) return false;
    if (kmRemaining <= ServiceThresholds.dueSoonKm) return true;
    final date = estimatedDate;
    if (date == null) return false;
    return date.difference(DateTime.now()).inDays <=
        ServiceThresholds.dueSoonDays;
  }

  /// Populated automatically the moment a log exists for this phase — no
  /// separate "mark complete" submission is required.
  DateTime? get completedDate => completedRecord?.date;

  int? get completedOdometer => completedRecord?.odometer;

  double get completedCost => completedRecord?.cost ?? 0;

  int get targetOdometer => milestone.targetOdometer;

  ServiceTier get tier => milestone.tier;

  @override
  List<Object?> get props => [
    milestone,
    kmRemaining,
    isCompleted,
    estimatedDate,
    completedRecord,
  ];
}
