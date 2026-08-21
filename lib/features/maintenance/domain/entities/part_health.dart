import 'package:equatable/equatable.dart';

import 'consumable_part.dart';

enum HealthStatus { healthy, dueSoon, overdue }

/// Computed remaining life of one wearing part — the model behind every
/// animated progress bar on the dashboard.
class PartHealth extends Equatable {
  const PartHealth({
    required this.part,
    required this.lifespanKm,
    required this.consumedKm,
    required this.remainingKm,
    required this.fractionRemaining,
    required this.lastServiceOdometer,
    this.lastServiceDate,
    this.estimatedDueDate,
    this.limitedByTime = false,
  });

  final ConsumablePart part;
  final int lifespanKm;
  final int consumedKm;
  final int remainingKm;

  /// 1.0 = brand new, 0.0 = fully consumed. Never negative, so a bar cannot
  /// render backwards when a service is overdue.
  final double fractionRemaining;

  final int lastServiceOdometer;
  final DateTime? lastServiceDate;

  /// When the part is expected to run out, projected from the driver average.
  final DateTime? estimatedDueDate;

  /// True when the calendar limit bites before the distance limit — the reason
  /// brake fluid can be "due" on a car that barely moves.
  final bool limitedByTime;

  HealthStatus get status {
    if (remainingKm <= 0) return HealthStatus.overdue;
    if (fractionRemaining <= 0.15) return HealthStatus.dueSoon;
    return HealthStatus.healthy;
  }

  bool get isOverdue => status == HealthStatus.overdue;

  int get dueAtOdometer => lastServiceOdometer + lifespanKm;

  @override
  List<Object?> get props => [
    part,
    lifespanKm,
    consumedKm,
    remainingKm,
    fractionRemaining,
    lastServiceOdometer,
    lastServiceDate,
    estimatedDueDate,
    limitedByTime,
  ];
}
