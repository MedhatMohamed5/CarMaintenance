import 'package:equatable/equatable.dart';

import 'maintenance_record.dart';
import 'service_milestone.dart';

enum DueDriver { distance, time }

class NextServiceDue extends Equatable {
  const NextServiceDue({
    required this.milestone,
    required this.targetOdometer,
    required this.kmRemaining,
    required this.dailyPace,
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

  ServiceTier get tier => milestone.tier;

  static const int dueSoonKm = 500;
  static const int dueSoonDays = 14;

  bool get isOverdue => kmRemaining < 0 || _timeOverdue;

  bool get isDueSoon =>
      !isOverdue && (kmRemaining <= dueSoonKm || _withinDays(dueSoonDays));

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
    targetDate,
    dueDriver,
    lastService,
    monthsSinceLastService,
  ];
}
