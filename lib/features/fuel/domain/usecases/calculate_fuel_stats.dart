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
/// The engine is also **odometer-aware**. Consumption and cost per kilometre
/// are not frozen at the moment a fill is logged: pass the vehicle's live
/// [currentOdometer] and the open tank, the stretch since the newest fill, is
/// measured against it. Every master-odometer update therefore lengthens the
/// measured distance and amortises the running cost downward, with no new fuel
/// entry required.
///
/// Pure and side-effect free, so it is trivially unit-testable and can be
/// reused verbatim on a server.
class CalculateFuelStats {
  const CalculateFuelStats();

  /// [currentOdometer] is the vehicle's master reading. When omitted, or behind
  /// the newest fill, it collapses to that fill's reading.
  FuelStats call(List<FuelLog> logs, {int? currentOdometer}) {
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

    final liveOdometer = _liveOdometer(ordered.last.odometer, currentOdometer);
    final openTank = _openTankOf(ordered, liveOdometer);

    // ---- the one accumulative span every headline divides by ----------
    //
    // First fill -> wherever the car is right now. Identical to "every closed
    // segment plus the open stretch", because the segments telescope: this is
    // exactly the distance the octane comparison already attributes across the
    // grades, so the header and the per-grade rows can never disagree.
    //
    // Numerators are the complete log history: every litre, every pound. No
    // metric on a summary card is scoped to the last fill or to one tank.
    final accumulativeDistance = FuelMath.distanceBetween(
      ordered.first.odometer,
      liveOdometer,
    );
    final accumulativeLitersPer100Km = FuelMath.litersPer100Km(
      liters: totalLiters,
      distanceKm: accumulativeDistance,
    );
    final accumulativeCostPerKm = FuelMath.costPerKm(
      totalCost: totalCost,
      distanceKm: accumulativeDistance,
    );

    if (segments.isEmpty) {
      // A lone fill, or several at the same reading: costs are known, the
      // consumption is not. Report what is real and leave the rest at zero.
      return FuelStats(
        segments: const [],
        byFuelType: _byFuelType(ordered, const [], openTank),
        avgEfficiency: 0,
        avgLitersPer100Km: 0,
        bestEfficiency: 0,
        worstEfficiency: 0,
        latestEfficiency: 0,
        latestLitersPer100Km: 0,
        avgCostPerKm: 0,
        avgPricePerLiter: FuelMath.pricePerLiter(
          totalCost: totalCost,
          liters: totalLiters,
        ),
        measuredDistanceKm: 0,
        measuredLiters: 0,
        liveDistanceKm: accumulativeDistance,
        liveLitersPer100Km: accumulativeLitersPer100Km,
        liveCostPerKm: accumulativeCostPerKm,
        openTank: openTank,
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
      byFuelType: _byFuelType(ordered, segments, openTank),
      // Distance-weighted by construction: driving 800 km on one tank counts
      // for more than a 40 km errand, because both feed the same two totals.
      avgEfficiency: FuelMath.kmPerLiter(
        liters: measuredLiters,
        distanceKm: measuredDistance,
      ),
      avgLitersPer100Km: FuelMath.litersPer100Km(
        liters: measuredLiters,
        distanceKm: measuredDistance,
      ),
      bestEfficiency: efficiencies.last,
      worstEfficiency: efficiencies.first,
      latestEfficiency: closing.efficiency,
      latestLitersPer100Km: closing.litersPer100Km,
      avgCostPerKm: FuelMath.costPerKm(
        totalCost: measuredCost,
        distanceKm: measuredDistance,
      ),
      avgPricePerLiter: FuelMath.pricePerLiter(
        totalCost: totalCost,
        liters: totalLiters,
      ),
      measuredDistanceKm: measuredDistance,
      measuredLiters: measuredLiters,
      liveDistanceKm: accumulativeDistance,
      liveLitersPer100Km: accumulativeLitersPer100Km,
      liveCostPerKm: accumulativeCostPerKm,
      openTank: openTank,
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

  /// A master reading behind the newest fill is a stale reading, not a
  /// negative distance: it collapses to the fill itself.
  int _liveOdometer(int newestFillOdometer, int? currentOdometer) =>
      currentOdometer == null || currentOdometer < newestFillOdometer
      ? newestFillOdometer
      : currentOdometer;

  /// The stretch since the newest fill, measured against the live odometer.
  ///
  /// Fills logged at the same reading are one visit to the pump as far as the
  /// driver is concerned, so their litres and cost are pooled.
  OpenTank _openTankOf(List<FuelLog> ordered, int liveOdometer) {
    final newest = ordered.last;
    var liters = 0.0;
    var cost = 0.0;
    for (final log in ordered.reversed) {
      if (log.odometer != newest.odometer) break;
      liters += log.liters;
      cost += log.totalCost;
    }
    return OpenTank(
      log: newest,
      currentOdometer: liveOdometer,
      liters: liters,
      cost: cost,
    );
  }

  /// Cumulative figures per fuel grade, so the user can see whether the pricier
  /// octane actually pays for itself.
  ///
  /// Volume and spend come from the **complete log history**, not just the
  /// fills that happened to close an interval, so a grade shows its real
  /// cumulative cost the moment it is bought. Distance comes from the closed
  /// segments that grade powered **plus the open stretch**, which is measured
  /// against the live odometer — so the grade currently in the tank keeps
  /// accruing kilometres between fills instead of stalling until the next one.
  List<FuelTypeStats> _byFuelType(
    List<FuelLog> ordered,
    List<FuelSegment> segments,
    OpenTank openTank,
  ) {
    final distanceByType = <FuelType, int>{};
    final segmentsByType = <FuelType, int>{};
    for (final s in segments) {
      distanceByType[s.fuelType] =
          (distanceByType[s.fuelType] ?? 0) + s.distanceKm;
      segmentsByType[s.fuelType] = (segmentsByType[s.fuelType] ?? 0) + 1;
    }
    if (openTank.hasDistance) {
      distanceByType[openTank.fuelType] =
          (distanceByType[openTank.fuelType] ?? 0) + openTank.distanceKm;
    }

    final litersByType = <FuelType, double>{};
    final costByType = <FuelType, double>{};
    for (final log in ordered) {
      litersByType[log.fuelType] =
          (litersByType[log.fuelType] ?? 0) + log.liters;
      costByType[log.fuelType] =
          (costByType[log.fuelType] ?? 0) + log.totalCost;
    }

    final grades = <FuelType>{...litersByType.keys, ...distanceByType.keys};

    final result = grades.map((type) {
      final distance = distanceByType[type] ?? 0;
      final liters = litersByType[type] ?? 0;
      final cost = costByType[type] ?? 0;
      return FuelTypeStats(
        fuelType: type,
        segments: segmentsByType[type] ?? 0,
        avgEfficiency: FuelMath.kmPerLiter(
          liters: liters,
          distanceKm: distance,
        ),
        avgLitersPer100Km: FuelMath.litersPer100Km(
          liters: liters,
          distanceKm: distance,
        ),
        avgCostPerKm: FuelMath.costPerKm(totalCost: cost, distanceKm: distance),
        avgPricePerLiter: FuelMath.pricePerLiter(
          totalCost: cost,
          liters: liters,
        ),
        totalDistanceKm: distance,
        totalLiters: liters,
        totalCost: cost,
      );
    }).toList();

    // Best economy first; grades bought but not yet driven on sort to the end
    // rather than disappearing.
    result.sort((a, b) => b.avgEfficiency.compareTo(a.avgEfficiency));
    return result;
  }

  double _avgDailyKm(int distance, DateTime first, DateTime last) =>
      FuelMath.kmPerDay(
        distanceKm: distance,
        days: DateX.daysBetween(first, last),
      );
}
