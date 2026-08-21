import 'package:equatable/equatable.dart';

import 'consumable_part.dart';

/// Wear bands. Thresholds are expressed on wear, and every colour, label and
/// icon in the UI derives from this single enum.
enum HealthStatus {
  /// 0–60% worn (40–100% life remaining).
  healthy(maxWear: 0.60),

  /// 61–85% worn (15–39% remaining).
  warning(maxWear: 0.85),

  /// 86%+ worn (0–14% remaining).
  critical(maxWear: 1.0);

  const HealthStatus({required this.maxWear});

  final double maxWear;

  static HealthStatus fromWear(double wear) {
    if (wear <= HealthStatus.healthy.maxWear) return HealthStatus.healthy;
    if (wear <= HealthStatus.warning.maxWear) return HealthStatus.warning;
    return HealthStatus.critical;
  }
}

/// Computed remaining life of one wearing part.
///
/// [wearFraction] is authoritative: it is the larger of the distance and
/// calendar budgets, clamped to 0..1. Everything else — remaining life,
/// status, colour — is derived from it, so `wear + remaining` is always 1.0.
class PartHealth extends Equatable {
  const PartHealth({
    required this.part,
    required this.lifespanKm,
    required this.lifespanMonths,
    required this.consumedKm,
    required this.wearFraction,
    required this.lastServiceOdometer,
    this.lastServiceDate,
    this.estimatedDueDate,
    this.limitedByTime = false,
  });

  final ConsumablePart part;
  final int lifespanKm;
  final int lifespanMonths;

  /// Raw distance since the last replacement, uncapped, for display.
  final int consumedKm;

  /// 0.0 = brand new, 1.0 = fully consumed. Never outside that range.
  final double wearFraction;

  final int lastServiceOdometer;
  final DateTime? lastServiceDate;
  final DateTime? estimatedDueDate;

  /// True when the calendar budget is further along than the distance budget.
  final bool limitedByTime;

  double get fractionRemaining => (1.0 - wearFraction).clamp(0.0, 1.0);

  double get wearPercentage => (wearFraction * 100).clamp(0.0, 100.0);

  double get remainingPercentage => (100.0 - wearPercentage).clamp(0.0, 100.0);

  int get wearPercent => wearPercentage.round();

  int get remainingPercent => remainingPercentage.round();

  /// Distance left on the effective (whichever-comes-first) budget.
  int get remainingKm => (lifespanKm * fractionRemaining).round();

  HealthStatus get status => HealthStatus.fromWear(wearFraction);

  bool get isCritical => status == HealthStatus.critical;

  bool get isOverdue => wearFraction >= 1.0;

  int get dueAtOdometer => lastServiceOdometer + lifespanKm;

  @override
  List<Object?> get props => [
    part,
    lifespanKm,
    lifespanMonths,
    consumedKm,
    wearFraction,
    lastServiceOdometer,
    lastServiceDate,
    estimatedDueDate,
    limitedByTime,
  ];
}
