import '../../../../core/utils/formatters.dart';
import '../entities/fuel_log.dart';
import '../entities/fuel_stats.dart';
import '../entities/fuel_type.dart';

/// The fuel consumption engine — rolling and accumulative.
///
/// There is no full-tank precondition. Every fill, partial or full, is a valid
/// data point: its litres are attributed to the distance covered since the
/// previous fill, and the headline figure is the accumulative ratio
///
///   `L/100km = (cumulative litres / cumulative distance) * 100`
///
/// Over a handful of fills a partial skews an individual interval, but the
/// accumulative ratio converges on the true consumption regardless of how the
/// user splits their purchases — which is the point: the user should never be
/// forced to fill the tank just to keep the app honest.
///
/// Fills that cover no distance (duplicate odometer, a correction, two pumps
/// in one stop) are never discarded; their litres and cost roll forward into
/// the next interval that does cover distance.
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

    final totalCost = ordered.fold<double>(0, (s, l) => s + l.totalCost);
    final totalLiters = ordered.fold<double>(0, (s, l) => s + l.liters);
    final firstDate = ordered
        .map((l) => l.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = ordered
        .map((l) => l.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final trackedDistance = ordered.last.odometer - ordered.first.odometer;

    final segments = _segmentsOf(ordered);

    if (segments.isEmpty) {
      // A lone fill, or several at the same reading: costs are known, the
      // consumption is not. Report what is real and leave the rest at zero.
      return FuelStats(
        segments: const [],
        byFuelType: const [],
        avgEfficiency: 0,
        avgLitersPer100Km: 0,
        bestEfficiency: 0,
        worstEfficiency: 0,
        latestEfficiency: 0,
        latestLitersPer100Km: 0,
        avgCostPerKm: 0,
        avgPricePerLiter: safeRate(totalCost, totalLiters),
        measuredDistanceKm: 0,
        measuredLiters: 0,
        totalLiters: totalLiters,
        totalCost: totalCost,
        totalDistanceKm: trackedDistance < 0 ? 0 : trackedDistance,
        avgDailyKm: _avgDailyKm(trackedDistance, firstDate, lastDate),
        firstLogDate: firstDate,
        lastLogDate: lastDate,
      );
    }

    // The last segment carries the running totals, so the accumulative average
    // is read off it rather than re-folded.
    final closing = segments.last;
    final measuredDistance = closing.cumulativeDistanceKm;
    final measuredLiters = closing.cumulativeLiters;
    final measuredCost = closing.cumulativeCost;

    final efficiencies = segments.map((s) => s.efficiency).toList()..sort();

    return FuelStats(
      segments: segments.reversed.toList(growable: false),
      byFuelType: _byFuelType(segments),
      // Distance-weighted by construction: driving 800 km on one tank counts
      // for more than a 40 km errand, because both feed the same two totals.
      avgEfficiency: safeRate(measuredDistance, measuredLiters),
      avgLitersPer100Km: safeRate(measuredLiters * 100, measuredDistance),
      bestEfficiency: efficiencies.last,
      worstEfficiency: efficiencies.first,
      latestEfficiency: closing.efficiency,
      latestLitersPer100Km: closing.litersPer100Km,
      avgCostPerKm: safeRate(measuredCost, measuredDistance),
      avgPricePerLiter: safeRate(totalCost, totalLiters),
      measuredDistanceKm: measuredDistance,
      measuredLiters: measuredLiters,
      totalLiters: totalLiters,
      totalCost: totalCost,
      totalDistanceKm: trackedDistance < 0 ? 0 : trackedDistance,
      avgDailyKm: _avgDailyKm(trackedDistance, firstDate, lastDate),
      firstLogDate: firstDate,
      lastLogDate: lastDate,
    );
  }

  /// Walks the ordered fills once, emitting one segment per interval that
  /// covers distance and carrying everything else forward.
  ///
  /// The first fill only anchors the odometer: the fuel bought there powers
  /// the interval that follows it, which has not been driven yet.
  List<FuelSegment> _segmentsOf(List<FuelLog> ordered) {
    final segments = <FuelSegment>[];

    var anchorOdometer = ordered.first.odometer;
    var pendingLiters = 0.0;
    var pendingCost = 0.0;
    var pendingFills = 0;

    var cumulativeDistance = 0;
    var cumulativeLiters = 0.0;
    var cumulativeCost = 0.0;

    for (final log in ordered.skip(1)) {
      pendingLiters += log.liters;
      pendingCost += log.totalCost;
      pendingFills += 1;

      final distance = log.odometer - anchorOdometer;
      // Nothing driven yet, or nothing poured yet: hold the litres and the
      // cost against the next interval instead of dropping the entry.
      if (distance <= 0 || pendingLiters <= 0) continue;

      cumulativeDistance += distance;
      cumulativeLiters += pendingLiters;
      cumulativeCost += pendingCost;

      segments.add(
        FuelSegment(
          log: log,
          previousOdometer: anchorOdometer,
          distanceKm: distance,
          litersUsed: pendingLiters,
          cost: pendingCost,
          cumulativeDistanceKm: cumulativeDistance,
          cumulativeLiters: cumulativeLiters,
          cumulativeCost: cumulativeCost,
          mergedFills: pendingFills,
        ),
      );

      anchorOdometer = log.odometer;
      pendingLiters = 0;
      pendingCost = 0;
      pendingFills = 0;
    }

    return segments;
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
        avgEfficiency: safeRate(distance, liters),
        avgLitersPer100Km: safeRate(liters * 100, distance),
        avgCostPerKm: safeRate(cost, distance),
        avgPricePerLiter: safeRate(cost, liters),
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
    return safeRate(distance, days);
  }
}
