import '../../../../core/utils/formatters.dart';
import '../entities/fuel_log.dart';
import '../entities/fuel_stats.dart';
import '../entities/fuel_type.dart';

/// The fuel consumption engine — rolling and accumulative.
///
/// There is no full-tank precondition. Every fill, partial or full, is a valid
/// data point, and the headline figure is the accumulative ratio
///
///   `L/100km = (cumulative litres / cumulative distance) * 100`
///
/// Over a handful of fills a partial skews an individual tank, but the
/// accumulative ratio converges on the true consumption regardless of how the
/// user splits their purchases — which is the point: the user should never be
/// forced to fill the tank just to keep the app honest.
///
/// **A fill powers the road after it, not the road before it.** Each tank runs
/// from the fill that opened it to the next one, and carries that fill's own
/// litres, money and grade. The previous model closed each stretch on the
/// *next* fill and took its grade and receipt, so switching from 92 to 95
/// charged a tank of 92 at the 95 price, labelled it 95, and credited 95 with
/// kilometres it never powered — and a price rise on the same grade did the
/// same to the tank bought before it. The rule here is also the one a driver
/// actually asks about: "after I put this in, how far did it take me, and what
/// did that cost?".
///
/// Fills logged at the same reading are one visit to the pump and pool into one
/// tank; a record with nothing poured is a reading, not a tank, and folds into
/// the tank already running.
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

    final tanks = _tanksOf(ordered);
    final segments = _segmentsOf(tanks);

    final liveOdometer = _liveOdometer(ordered.last.odometer, currentOdometer);
    final last = tanks.last;
    final openTank = OpenTank(
      log: last.log,
      currentOdometer: liveOdometer,
      liters: last.liters,
      cost: last.cost,
    );

    // ---- the one accumulative span every headline divides by ----------
    //
    // First fill -> wherever the car is right now. Identical to "every closed
    // tank plus the open one", because the tanks telescope: this is exactly
    // the distance the grade comparison attributes across the grades, so the
    // header and the per-grade rows can never disagree.
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
      // One tank, still running: costs are known, no tank has closed yet.
      // Report what is real and leave the settled figures at zero.
      return FuelStats(
        segments: const [],
        byFuelType: _byFuelType(segments, openTank),
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

    // The newest closed tank carries the running totals, so the settled
    // average is read off it rather than re-folded.
    final closing = segments.last;
    final measuredDistance = closing.cumulativeDistanceKm;
    final measuredLiters = closing.cumulativeLiters;
    final measuredCost = closing.cumulativeCost;

    final efficiencies = segments.map((s) => s.efficiency).toList()..sort();

    return FuelStats(
      segments: segments.reversed.toList(growable: false),
      byFuelType: _byFuelType(segments, openTank),
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

  /// Groups the ordered fills into tanks, oldest first.
  ///
  /// A new tank opens at every fill that poured something at a reading beyond
  /// the current tank's. Everything else joins the tank already running: a
  /// second pump at the same stop is the same visit, and a record with no
  /// volume is an odometer reading, not fuel that can power anything.
  List<_Tank> _tanksOf(List<FuelLog> ordered) {
    final tanks = <_Tank>[];
    for (final log in ordered) {
      final running = tanks.isEmpty ? null : tanks.last;
      if (running != null &&
          (log.odometer == running.odometer || !log.hasVolume)) {
        running.add(log);
      } else {
        tanks.add(_Tank(log));
      }
    }
    return tanks;
  }

  /// One segment per closed tank: from the fill that opened it to the one
  /// that opened the next. The newest tank is still running and is the open
  /// tank, not a segment.
  List<FuelSegment> _segmentsOf(List<_Tank> tanks) {
    final segments = <FuelSegment>[];

    var cumulativeDistance = 0;
    var cumulativeLiters = 0.0;
    var cumulativeCost = 0.0;

    for (var i = 0; i < tanks.length - 1; i++) {
      final tank = tanks[i];
      final next = tanks[i + 1];
      final distance = next.odometer - tank.odometer;
      // Only a lone opening record with nothing poured lands here: it anchors
      // the odometer but holds no fuel to measure.
      if (distance <= 0 || tank.liters <= 0) continue;

      cumulativeDistance += distance;
      cumulativeLiters += tank.liters;
      cumulativeCost += tank.cost;

      segments.add(
        FuelSegment(
          log: tank.log,
          endOdometer: next.odometer,
          endDate: next.log.date,
          distanceKm: distance,
          litersUsed: tank.liters,
          cost: tank.cost,
          cumulativeDistanceKm: cumulativeDistance,
          cumulativeLiters: cumulativeLiters,
          cumulativeCost: cumulativeCost,
          mergedFills: tank.fills,
        ),
      );
    }

    return segments;
  }

  /// A master reading behind the newest fill is a stale reading, not a
  /// negative distance: it collapses to the fill itself.
  int _liveOdometer(int newestFillOdometer, int? currentOdometer) =>
      currentOdometer == null || currentOdometer < newestFillOdometer
      ? newestFillOdometer
      : currentOdometer;

  /// Cumulative figures per fuel grade, so the user can see whether the pricier
  /// octane actually pays for itself.
  ///
  /// Built from the tanks, so each grade's litres, money and kilometres come
  /// from the same fills: a grade is charged what was paid for it, over the
  /// road it powered. The open tank counts too, measured against the live
  /// odometer — the grade currently in the tank keeps accruing kilometres
  /// between fills instead of stalling until the next one, and the rows sum to
  /// exactly the header's totals.
  List<FuelTypeStats> _byFuelType(
    List<FuelSegment> segments,
    OpenTank openTank,
  ) {
    final distanceByType = <FuelType, int>{};
    final segmentsByType = <FuelType, int>{};
    final litersByType = <FuelType, double>{};
    final costByType = <FuelType, double>{};

    void add(FuelType type, int distance, double liters, double cost) {
      distanceByType[type] = (distanceByType[type] ?? 0) + distance;
      litersByType[type] = (litersByType[type] ?? 0) + liters;
      costByType[type] = (costByType[type] ?? 0) + cost;
    }

    for (final s in segments) {
      add(s.fuelType, s.distanceKm, s.litersUsed, s.cost);
      segmentsByType[s.fuelType] = (segmentsByType[s.fuelType] ?? 0) + 1;
    }
    add(openTank.fuelType, openTank.distanceKm, openTank.liters, openTank.cost);

    final result = litersByType.keys.map((type) {
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

    // Cheapest per kilometre first — "is 95 worth it?" is a question about
    // money, not litres. A grade bought but not yet driven on has no cost per
    // kilometre; its `0.0` would otherwise rank it cheapest, so it sorts to
    // the end instead of disappearing.
    result.sort((a, b) {
      if (a.isMeasured != b.isMeasured) return a.isMeasured ? -1 : 1;
      return a.avgCostPerKm.compareTo(b.avgCostPerKm);
    });
    return result;
  }

  double _avgDailyKm(int distance, DateTime first, DateTime last) =>
      FuelMath.kmPerDay(
        distanceKm: distance,
        days: DateX.daysBetween(first, last),
      );
}

/// The fuel bought at one visit to the pump, pooled with any record that
/// joined it before the next visit.
class _Tank {
  _Tank(FuelLog first)
    : log = first,
      odometer = first.odometer,
      liters = first.liters,
      cost = first.totalCost;

  /// The fill that opened the tank — the newest one at the opening reading
  /// that poured something, so its row in the history is the one that shows
  /// the tank.
  FuelLog log;
  final int odometer;
  double liters;
  double cost;
  int fills = 1;

  void add(FuelLog other) {
    liters += other.liters;
    cost += other.totalCost;
    fills += 1;
    if (other.odometer == odometer && other.hasVolume) log = other;
  }
}
