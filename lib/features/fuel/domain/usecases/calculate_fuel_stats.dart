import '../../../../core/utils/formatters.dart';
import '../entities/fuel_log.dart';
import '../entities/fuel_stats.dart';
import '../entities/fuel_type.dart';

/// The fuel efficiency engine.
///
/// Method: the **full-to-full** rule. Consumption can only be measured over a
/// stretch that begins and ends with a full tank, because only then is the
/// amount burned exactly equal to the amount poured in at the end. A partial
/// fill in between does not break the chain — its litres are added to the
/// running total and the segment simply spans further.
///
/// Pure and side-effect free, so it is trivially unit-testable and can be
/// reused verbatim on a server.
class CalculateFuelStats {
  const CalculateFuelStats();

  FuelStats call(List<FuelLog> logs) {
    if (logs.isEmpty) return const FuelStats.empty();

    // Chronological by odometer; the odometer is the physical truth even if
    // two entries share a date.
    final ordered = [...logs]
      ..sort((a, b) {
        final byOdo = a.odometer.compareTo(b.odometer);
        return byOdo != 0 ? byOdo : a.date.compareTo(b.date);
      });

    final segments = <FuelSegment>[];

    // Anchor = the last full tank we saw. Everything poured in after it is
    // accumulated until the next full tank closes the measurement.
    FuelLog? anchor;
    double pendingLiters = 0;
    double pendingCost = 0;

    for (final log in ordered) {
      if (anchor == null) {
        // Nothing measurable before the first full tank.
        if (log.isFullTank) anchor = log;
        continue;
      }

      pendingLiters += log.liters;
      pendingCost += log.totalCost;

      if (!log.isFullTank) continue;

      final distance = log.odometer - anchor.odometer;
      // Guard against duplicate or mistyped readings producing infinities.
      if (distance > 0 && pendingLiters > 0) {
        segments.add(
          FuelSegment(
            log: log,
            previousOdometer: anchor.odometer,
            distanceKm: distance,
            litersUsed: pendingLiters,
            cost: pendingCost,
          ),
        );
      }
      anchor = log;
      pendingLiters = 0;
      pendingCost = 0;
    }

    final totalCost = ordered.fold<double>(0, (s, l) => s + l.totalCost);
    final totalLiters = ordered.fold<double>(0, (s, l) => s + l.liters);
    final firstDate = ordered
        .map((l) => l.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = ordered
        .map((l) => l.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    if (segments.isEmpty) {
      return FuelStats(
        segments: const [],
        byFuelType: const [],
        avgEfficiency: 0,
        bestEfficiency: 0,
        worstEfficiency: 0,
        latestEfficiency: 0,
        avgCostPerKm: 0,
        totalLiters: totalLiters,
        totalCost: totalCost,
        totalDistanceKm: ordered.last.odometer - ordered.first.odometer,
        avgDailyKm: _avgDailyKm(
          ordered.last.odometer - ordered.first.odometer,
          firstDate,
          lastDate,
        ),
        firstLogDate: firstDate,
        lastLogDate: lastDate,
      );
    }

    final measuredDistance = segments.fold<int>(0, (s, x) => s + x.distanceKm);
    final measuredLiters = segments.fold<double>(0, (s, x) => s + x.litersUsed);
    final measuredCost = segments.fold<double>(0, (s, x) => s + x.cost);

    // Weighted by distance, not a mean of ratios: driving 800 km on one tank
    // should count more than a 40 km errand.
    final avgEfficiency = measuredLiters <= 0
        ? 0.0
        : measuredDistance / measuredLiters;
    final avgCostPerKm = measuredDistance <= 0
        ? 0.0
        : measuredCost / measuredDistance;

    final efficiencies = segments.map((s) => s.efficiency).toList()..sort();

    return FuelStats(
      segments: segments.reversed.toList(growable: false),
      byFuelType: _byFuelType(segments),
      avgEfficiency: avgEfficiency,
      bestEfficiency: efficiencies.last,
      worstEfficiency: efficiencies.first,
      latestEfficiency: segments.last.efficiency,
      avgCostPerKm: avgCostPerKm,
      totalLiters: totalLiters,
      totalCost: totalCost,
      totalDistanceKm: ordered.last.odometer - ordered.first.odometer,
      avgDailyKm: _avgDailyKm(
        ordered.last.odometer - ordered.first.odometer,
        firstDate,
        lastDate,
      ),
      firstLogDate: firstDate,
      lastLogDate: lastDate,
    );
  }

  /// Groups measured segments by the grade that was burned, so the user can
  /// see whether the pricier octane actually pays for itself.
  List<FuelTypeStats> _byFuelType(List<FuelSegment> segments) {
    final grouped = <FuelType, List<FuelSegment>>{};
    for (final s in segments) {
      grouped.putIfAbsent(s.fuelType, () => []).add(s);
    }

    final result = grouped.entries.map((entry) {
      final list = entry.value;
      final distance = list.fold<int>(0, (s, x) => s + x.distanceKm);
      final liters = list.fold<double>(0, (s, x) => s + x.litersUsed);
      final cost = list.fold<double>(0, (s, x) => s + x.cost);
      return FuelTypeStats(
        fuelType: entry.key,
        segments: list.length,
        avgEfficiency: liters <= 0 ? 0 : distance / liters,
        avgCostPerKm: distance <= 0 ? 0 : cost / distance,
        avgPricePerLiter: liters <= 0 ? 0 : cost / liters,
        totalDistanceKm: distance,
        totalLiters: liters,
        totalCost: cost,
      );
    }).toList();

    result.sort((a, b) => b.avgEfficiency.compareTo(a.avgEfficiency));
    return result;
  }

  double _avgDailyKm(int distance, DateTime first, DateTime last) {
    final days = DateX.daysBetween(first, last);
    if (days <= 0 || distance <= 0) return 0;
    return distance / days;
  }
}
