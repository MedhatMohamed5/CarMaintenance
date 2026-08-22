import 'package:equatable/equatable.dart';

import 'consumable_part.dart';
import 'part_setting.dart';

/// Wear bands, expressed on wear. Every colour, label and icon derives from
/// this enum, so thresholds live in exactly one place.
enum HealthStatus {
  /// 0–60% worn (40–100% life remaining).
  healthy(maxWear: 0.60),

  /// 61–85% worn (15–39% remaining).
  warning(maxWear: 0.85),

  /// 86%+ worn (0–14% remaining), including anything past 100%.
  critical(maxWear: double.infinity);

  const HealthStatus({required this.maxWear});

  final double maxWear;

  static HealthStatus fromWear(double wear) {
    if (wear <= HealthStatus.healthy.maxWear) return HealthStatus.healthy;
    if (wear <= HealthStatus.warning.maxWear) return HealthStatus.warning;
    return HealthStatus.critical;
  }
}

/// Computed condition of one consumable part.
///
/// [rawWearFraction] is uncapped so an overrun surfaces as "112% — replace
/// now"; [wearFraction] is the 0..1 version that drives progress bars.
class PartHealth extends Equatable {
  const PartHealth({
    required this.part,
    required this.intervalKm,
    required this.intervalMonths,
    required this.distanceDriven,
    required this.rawWearFraction,
    required this.lastReplacedOdometer,
    required this.baselineSource,
    this.lastReplacedDate,
    this.estimatedDueDate,
    this.limitedByTime = false,
  });

  final ConsumablePart part;

  /// Effective lifespan for this vehicle, after any per-part override.
  final int intervalKm;
  final int intervalMonths;

  /// `currentOdometer - lastReplacedOdometer`.
  final int distanceDriven;

  /// Uncapped wear; may exceed 1.0.
  final double rawWearFraction;

  final int lastReplacedOdometer;
  final PartBaselineSource baselineSource;
  final DateTime? lastReplacedDate;
  final DateTime? estimatedDueDate;
  final bool limitedByTime;

  /// Clamped 0..1 — safe for progress bars.
  double get wearFraction => rawWearFraction.clamp(0.0, 1.0);

  double get fractionRemaining => 1.0 - wearFraction;

  /// Uncapped percentage: 112.0 means 12% past the interval.
  double get wearPercentage => (rawWearFraction * 100).clamp(0.0, 999.0);

  double get remainingPercentage => (100.0 - wearPercentage).clamp(0.0, 100.0);

  int get wearPercent => wearPercentage.round();

  int get remainingPercent => remainingPercentage.round();

  /// `intervalKm - distanceDriven`, floored at zero for display.
  int get remainingKm =>
      (intervalKm - distanceDriven) < 0 ? 0 : intervalKm - distanceDriven;

  /// Negative once the interval is exceeded — how far past it the part is.
  int get overrunKm =>
      distanceDriven > intervalKm ? distanceDriven - intervalKm : 0;

  HealthStatus get status => HealthStatus.fromWear(rawWearFraction);

  bool get isCritical => status == HealthStatus.critical;

  /// Past its interval — distinct from merely critical.
  bool get isOverLimit => rawWearFraction > 1.0;

  bool get isOverdue => rawWearFraction >= 1.0;

  bool get isUserDefined =>
      baselineSource == PartBaselineSource.manual ||
      baselineSource == PartBaselineSource.customWear;

  int get dueAtOdometer => lastReplacedOdometer + intervalKm;

  @override
  List<Object?> get props => [
    part,
    intervalKm,
    intervalMonths,
    distanceDriven,
    rawWearFraction,
    lastReplacedOdometer,
    baselineSource,
    lastReplacedDate,
    estimatedDueDate,
    limitedByTime,
  ];
}
