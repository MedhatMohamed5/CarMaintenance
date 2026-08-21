import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/consumable_part.dart';
import '../entities/part_health.dart';
import '../entities/part_replacement.dart';

/// Turns replacement history into the remaining-life figures the dashboard
/// visualises.
///
/// A part is measured from the most recent evidence that it was fitted new. If
/// there is none, the baseline is the odometer the vehicle was added at — the
/// honest assumption being "we have no idea what happened before, so start
/// counting from when we started watching".
class CalculatePartsHealth {
  const CalculatePartsHealth();

  /// Average kilometres per day, used only to project a due *date*.
  List<PartHealth> call({
    required Vehicle vehicle,
    required List<PartReplacement> replacements,
    List<ConsumablePart> parts = ConsumablePart.dashboardOrder,
    double avgDailyKm = 0,
  }) {
    // Latest replacement per part, by odometer.
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

    final baseOdometer =
        last?.odometer ?? _assumedBaseline(vehicle.initialOdometer, lifespanKm);
    final baseDate =
        last?.date ??
        _assumedBaseDate(
          vehicle.purchaseDate ?? vehicle.createdAt,
          part.defaultLifespanMonths,
          vehicle.initialOdometer,
          lifespanKm,
        );

    final consumedKm = (vehicle.currentOdometer - baseOdometer).clamp(
      0,
      1 << 31,
    );

    // Distance budget.
    var remainingKm = lifespanKm - consumedKm;

    // Calendar budget, converted to an equivalent distance so both limits can
    // be compared on one bar. Fluids that degrade with age bite here.
    final monthsElapsed = _monthsBetween(baseDate, DateTime.now());
    final monthsRemaining = part.defaultLifespanMonths - monthsElapsed;
    final timeFraction = part.defaultLifespanMonths <= 0
        ? 1.0
        : (monthsRemaining / part.defaultLifespanMonths).clamp(0.0, 1.0);
    final distanceFraction = lifespanKm <= 0
        ? 1.0
        : (remainingKm / lifespanKm).clamp(0.0, 1.0);

    final limitedByTime = timeFraction < distanceFraction;
    final fraction = limitedByTime ? timeFraction : distanceFraction;
    if (limitedByTime) {
      // Report the distance the *effective* budget leaves, so the number under
      // the bar always agrees with the bar itself.
      remainingKm = (lifespanKm * timeFraction).round();
    }

    return PartHealth(
      part: part,
      lifespanKm: lifespanKm,
      consumedKm: consumedKm,
      remainingKm: remainingKm < 0 ? 0 : remainingKm,
      fractionRemaining: fraction.toDouble(),
      lastServiceOdometer: baseOdometer,
      lastServiceDate: last?.date,
      estimatedDueDate: _projectDate(
        remainingKm: lifespanKm - consumedKm,
        avgDailyKm: avgDailyKm,
        calendarDue: _addMonths(baseDate, part.defaultLifespanMonths),
      ),
      limitedByTime: limitedByTime,
    );
  }

  /// Whichever comes first: the day the distance runs out at the driver's own
  /// pace, or the calendar limit.
  DateTime? _projectDate({
    required int remainingKm,
    required double avgDailyKm,
    required DateTime calendarDue,
  }) {
    if (avgDailyKm <= 0) return calendarDue;
    final days = (remainingKm / avgDailyKm).round();
    final distanceDue = DateTime.now().add(Duration(days: days));
    return distanceDue.isBefore(calendarDue) ? distanceDue : calendarDue;
  }

  /// A vehicle joining the app at 50,000 km has not just had everything
  /// replaced. With no history to go on, each part is assumed to have been
  /// serviced at the last standard cycle boundary it passed, so a 40,000 km
  /// tyre set reads 10,000 km worn rather than brand new.
  static int _assumedBaseline(int initialOdometer, int lifespanKm) {
    if (initialOdometer <= 0 || lifespanKm <= 0) return 0;
    return initialOdometer - (initialOdometer % lifespanKm);
  }

  /// The matching calendar assumption: the part is aged by the same fraction
  /// of its rated life that the odometer implies.
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
    final agedMonths = (lifespanMonths * consumedFraction).round();
    return _addMonths(anchor, -agedMonths);
  }

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    return DateTime(d.year + total ~/ 12, total % 12 + 1, d.day);
  }
}
