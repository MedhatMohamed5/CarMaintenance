import '../../../../core/constants/service_thresholds.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/consumable_part.dart';
import '../entities/part_health.dart';
import '../entities/part_replacement.dart';
import '../entities/part_setting.dart';

/// Resolves each part's baseline independently, then measures wear from it.
///
/// Baseline priority, highest first:
///   1. pinned wear percentage      (`PartSetting.customWear`)
///   2. explicit odometer           (`PartSetting.lastReplacedOdometer`)
///   3. newest logged replacement   (`PartReplacement`)
///   4. inferred milestone          (nearest interval below the initial reading)
///
/// Every part resolves on its own, so replacing brake pads at 42,000 km moves
/// only the brake-pad baseline and leaves engine oil measured from its own.
class CalculatePartsHealth {
  const CalculatePartsHealth();

  List<PartHealth> call({
    required Vehicle vehicle,
    required List<PartReplacement> replacements,
    List<ConsumablePart> parts = ConsumablePart.dashboardOrder,
    double avgDailyKm = 0,
  }) {
    final latest = <ConsumablePart, PartReplacement>{};
    for (final r in replacements) {
      if (r.vehicleId != vehicle.id) continue;
      final existing = latest[r.part];
      if (existing == null || r.odometer > existing.odometer) {
        latest[r.part] = r;
      }
    }

    return parts
        .map(
          (part) => _healthOf(
            part: part,
            vehicle: vehicle,
            last: latest[part],
            avgDailyKm: avgDailyKm,
          ),
        )
        .toList(growable: false);
  }

  PartHealth _healthOf({
    required ConsumablePart part,
    required Vehicle vehicle,
    required PartReplacement? last,
    required double avgDailyKm,
  }) {
    final setting = vehicle.settingFor(part.id);
    final intervalKm = setting.intervalKm ?? part.defaultLifespanKm;
    final intervalMonths = part.defaultLifespanMonths;

    final (baseOdometer, source) = _resolveBaseline(
      setting: setting,
      last: last,
      initialOdometer: vehicle.initialOdometer,
      currentOdometer: vehicle.currentOdometer,
      intervalKm: intervalKm,
    );

    final baseDate =
        setting.lastReplacedDate ??
        last?.date ??
        _assumedBaseDate(
          vehicle.createdAt,
          intervalMonths,
          vehicle.initialOdometer,
          intervalKm,
        );

    // Distance Driven on Part = Current Odometer - Part Last Replaced Odometer
    final distanceDriven = (vehicle.currentOdometer - baseOdometer)
        .clamp(0, 1 << 31)
        .toInt();

    final distanceWear = intervalKm <= 0 ? 0.0 : distanceDriven / intervalKm;

    final monthsElapsed = _monthsBetween(baseDate, DateTime.now());
    final timeWear = intervalMonths <= 0
        ? 0.0
        : (monthsElapsed / intervalMonths).clamp(0.0, 1.0);

    // A pinned percentage wins outright; otherwise whichever budget is further
    // along. Raw wear is left uncapped so >100% can be surfaced as critical.
    final double rawWear;
    final bool limitedByTime;
    if (setting.customWear != null) {
      rawWear = setting.customWear!.clamp(0.0, 10.0);
      limitedByTime = false;
    } else {
      limitedByTime = timeWear > distanceWear;
      rawWear = limitedByTime ? timeWear : distanceWear;
    }

    return PartHealth(
      part: part,
      intervalKm: intervalKm,
      intervalMonths: intervalMonths,
      distanceDriven: distanceDriven,
      rawWearFraction: rawWear.toDouble(),
      lastReplacedOdometer: baseOdometer,
      baselineSource: source,
      lastReplacedDate: setting.lastReplacedDate ?? last?.date,
      estimatedDueDate: _projectDate(
        remainingKm: intervalKm - distanceDriven,
        avgDailyKm: avgDailyKm,
        calendarDue: _addMonths(baseDate, intervalMonths),
      ),
      limitedByTime: limitedByTime,
    );
  }

  (int, PartBaselineSource) _resolveBaseline({
    required PartSetting setting,
    required PartReplacement? last,
    required int initialOdometer,
    required int currentOdometer,
    required int intervalKm,
  }) {
    if (setting.customWear != null) {
      final implied = currentOdometer - (intervalKm * setting.customWear!);
      return (implied.round(), PartBaselineSource.customWear);
    }

    final manual = setting.lastReplacedOdometer;
    if (manual != null) return (manual, PartBaselineSource.manual);

    if (last != null) return (last.odometer, PartBaselineSource.logged);

    return (
      _assumedBaseline(initialOdometer, intervalKm),
      PartBaselineSource.assumed,
    );
  }

  DateTime? _projectDate({
    required int remainingKm,
    required double avgDailyKm,
    required DateTime calendarDue,
  }) {
    if (avgDailyKm <= 0) return calendarDue;
    final days = (remainingKm / avgDailyKm).round().clamp(
      -ProjectionLimits.horizonDays,
      ProjectionLimits.horizonDays,
    );
    final distanceDue = DateTime.now().add(Duration(days: days));
    return distanceDue.isBefore(calendarDue) ? distanceDue : calendarDue;
  }

  /// A vehicle joining at 45,000 km has not just had everything replaced.
  /// With no history, each part is assumed serviced at the nearest interval
  /// boundary below that reading — engine oil at 40,000, not at zero.
  static int _assumedBaseline(int initialOdometer, int intervalKm) {
    if (initialOdometer <= 0 || intervalKm <= 0) return 0;
    return initialOdometer - (initialOdometer % intervalKm);
  }

  /// Calendar baseline anchored to the day the vehicle joined the app,
  /// back-dated by the fraction the odometer implies. Deliberately not
  /// anchored to `purchaseDate`, which would put every short-life part past
  /// its calendar limit the moment an older car is added.
  static DateTime _assumedBaseDate(
    DateTime anchor,
    int intervalMonths,
    int initialOdometer,
    int intervalKm,
  ) {
    if (initialOdometer <= 0 || intervalKm <= 0 || intervalMonths <= 0) {
      return anchor;
    }
    final consumedFraction = ((initialOdometer % intervalKm) / intervalKm)
        .clamp(0.0, 1.0);
    return _addMonths(anchor, -(intervalMonths * consumedFraction).round());
  }

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    return DateTime(d.year + total ~/ 12, total % 12 + 1, d.day);
  }
}
