import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/consumable_part.dart';
import '../entities/part_health.dart';
import '../entities/part_replacement.dart';

/// Turns replacement history into remaining-life figures.
///
/// Wear is `(currentOdometer - lastReplacedOdometer) / lifespanKm`, compared
/// against the calendar budget `monthsElapsed / lifespanMonths`. Whichever is
/// further along wins — "whichever comes first" — and the result is clamped to
/// 0..1 so an overdue part reads exactly 100%, never more.
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
    final lifespanKm =
        vehicle.partLifespanOverridesKm[part.id] ?? part.defaultLifespanKm;
    final lifespanMonths = part.defaultLifespanMonths;

    final baseOdometer =
        last?.odometer ?? _assumedBaseline(vehicle.initialOdometer, lifespanKm);
    final baseDate =
        last?.date ??
        _assumedBaseDate(
          vehicle.purchaseDate ?? vehicle.createdAt,
          lifespanMonths,
          vehicle.initialOdometer,
          lifespanKm,
        );

    final consumedKm = (vehicle.currentOdometer - baseOdometer)
        .clamp(0, 1 << 31)
        .toInt();

    final distanceWear = lifespanKm <= 0 ? 0.0 : consumedKm / lifespanKm;

    final monthsElapsed = _monthsBetween(baseDate, DateTime.now());
    final timeWear = lifespanMonths <= 0
        ? 0.0
        : monthsElapsed / lifespanMonths;

    final limitedByTime = timeWear > distanceWear;
    final wear = (limitedByTime ? timeWear : distanceWear).clamp(0.0, 1.0);

    return PartHealth(
      part: part,
      lifespanKm: lifespanKm,
      lifespanMonths: lifespanMonths,
      consumedKm: consumedKm,
      wearFraction: wear.toDouble(),
      lastServiceOdometer: baseOdometer,
      lastServiceDate: last?.date,
      estimatedDueDate: _projectDate(
        remainingKm: lifespanKm - consumedKm,
        avgDailyKm: avgDailyKm,
        calendarDue: _addMonths(baseDate, lifespanMonths),
      ),
      limitedByTime: limitedByTime,
    );
  }

  DateTime? _projectDate({
    required int remainingKm,
    required double avgDailyKm,
    required DateTime calendarDue,
  }) {
    if (avgDailyKm <= 0) return calendarDue;
    final days = (remainingKm / avgDailyKm).round().clamp(-36500, 36500);
    final distanceDue = DateTime.now().add(Duration(days: days));
    return distanceDue.isBefore(calendarDue) ? distanceDue : calendarDue;
  }

  /// A vehicle joining the app at 50,000 km has not just had everything
  /// replaced. With no history, each part is assumed serviced at the last
  /// standard cycle boundary it passed.
  static int _assumedBaseline(int initialOdometer, int lifespanKm) {
    if (initialOdometer <= 0 || lifespanKm <= 0) return 0;
    return initialOdometer - (initialOdometer % lifespanKm);
  }

  static DateTime _assumedBaseDate(
    DateTime anchor,
    int lifespanMonths,
    int initialOdometer,
    int lifespanKm,
  ) {
    if (initialOdometer <= 0 || lifespanKm <= 0 || lifespanMonths <= 0) {
      return anchor;
    }
    final consumedFraction = (initialOdometer % lifespanKm) / lifespanKm;
    return _addMonths(anchor, -(lifespanMonths * consumedFraction).round());
  }

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    return DateTime(d.year + total ~/ 12, total % 12 + 1, d.day);
  }
}
