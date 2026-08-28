import '../../../../core/constants/service_thresholds.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../fuel/domain/entities/fuel_log.dart';
import '../../../fuel/domain/fuel_math.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/domain/entities/upcoming_service.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../entities/vehicle_forecast.dart';
import '../entities/vehicle_metrics.dart';

/// Insurance and licensing, split into the rate to project forward and the
/// history to subtract from the per-kilometre pot.
class _Policy {
  const _Policy({required this.monthly, required this.historicalTotal});

  final double monthly;
  final double historicalTotal;
}

class _OdometerSample {
  const _OdometerSample({required this.date, required this.odometer});

  final DateTime date;
  final int odometer;
}

/// Builds a [VehicleForecast] from the active vehicle's logged history.
///
/// Daily pace is the first-to-last odometer span divided by the calendar days
/// between those readings — the same km-per-day formula the fuel engine uses,
/// applied to every dated odometer observation (fills, services, expenses and
/// the vehicle's own baseline). Maintenance dates are remaining kilometres
/// over that pace. Spend projections are historical cost per kilometre times
/// projected monthly and yearly distance.
class ComputeVehicleForecast {
  const ComputeVehicleForecast();

  static const double daysPerMonth = 30.4375;
  static const double daysPerYear = 365.25;

  /// Insurance is written a year at a time.
  static const int _insuranceTermMonths = 12;

  /// The two licence terms on offer.
  static const int _licenseTermMonths1Year = 12;
  static const int _licenseTermMonths3Year = 36;

  VehicleForecast call({
    required Vehicle vehicle,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> records,
    required List<Expense> expenses,
    required List<UpcomingService> upcoming,
    required List<PartHealth> parts,
    required VehicleMetrics metrics,
  }) {
    final samples = _samples(
      vehicle: vehicle,
      fuelLogs: fuelLogs,
      records: records,
      expenses: expenses,
    );
    final pace = _dailyPace(samples);
    final spanDays = samples.length < 2
        ? 0
        : _daysBetween(samples.first.date, samples.last.date);

    if (pace <= 0 || samples.length < 2 || spanDays <= 0) {
      return VehicleForecast.empty(
        observationCount: samples.length,
        fuelLogCount: fuelLogs.length,
      );
    }

    final monthlyKm = pace * daysPerMonth;
    final yearlyKm = pace * daysPerYear;

    final fuelPerKm = metrics.fuelCostPerKm;
    final maintPerKm = FuelMath.costPerKm(
      totalCost: metrics.serviceCost + metrics.partsCost,
      distanceKm: metrics.trackedDistanceKm,
    );
    // Insurance and licensing come out of the per-kilometre pot entirely and
    // are amortised over calendar months instead. Left in, they inflated the
    // `other` rate for every kilometre driven since the vehicle joined, and a
    // renewal landing inside the tracked span made the projection jump.
    final policy = _amortisedPolicy(vehicle: vehicle, expenses: expenses);
    final otherPerKm = FuelMath.costPerKm(
      totalCost: (metrics.otherCost - policy.historicalTotal).clamp(
        0.0,
        double.infinity,
      ),
      distanceKm: metrics.trackedDistanceKm,
    );

    return VehicleForecast(
      hasEnoughData: true,
      observationCount: samples.length,
      fuelLogCount: fuelLogs.length,
      spanDays: spanDays,
      avgDailyKm: pace,
      projectedMonthlyKm: monthlyKm,
      projectedYearlyKm: yearlyKm,
      litersPer100Km: metrics.litersPer100Km,
      fuelCostPerKm: fuelPerKm,
      monthlyFuelCost: fuelPerKm * monthlyKm,
      yearlyFuelCost: fuelPerKm * yearlyKm,
      monthlyLiters: FuelMath.safeDivide(
        metrics.litersPer100Km * monthlyKm,
        100,
      ),
      yearlyLiters: FuelMath.safeDivide(metrics.litersPer100Km * yearlyKm, 100),
      monthlyMaintenanceCost: maintPerKm * monthlyKm,
      yearlyMaintenanceCost: maintPerKm * yearlyKm,
      monthlyOtherCost: otherPerKm * monthlyKm,
      yearlyOtherCost: otherPerKm * yearlyKm,
      monthlyPolicyCost: policy.monthly,
      yearlyPolicyCost: policy.monthly * 12,
      services: [
        for (final item in upcoming)
          if (!item.isCompleted)
            ForecastItem(
              l10nKey: item.milestone.tier.l10nKey,
              remainingKm: item.kmRemaining,
              targetOdometer: item.milestone.targetOdometer,
              isOverdue: item.kmRemaining < 0,
              colorValue: item.milestone.tier.colorValue,
              projectedDate: _projectDate(item.kmRemaining, pace),
            ),
      ],
      parts: [
        for (final part in parts)
          ForecastItem(
            l10nKey: part.part.l10nKey,
            remainingKm: part.remainingKm,
            targetOdometer: part.dueAtOdometer,
            isOverdue: part.isOverdue,
            colorValue: part.part.colorValue,
            projectedDate: _projectDate(part.remainingKm, pace),
            remainingFraction: part.fractionRemaining,
            iconKey: part.part.iconKey,
          ),
      ],
    );
  }

  /// Insurance and licensing, reduced to a monthly rate.
  ///
  /// **The most recent payment in each category, not the sum of them.** These
  /// renew, so the history holds one figure per term; adding three years of
  /// licence receipts together and dividing by one term would treble the rate.
  /// What the driver needs to set aside is what the cover in force costs.
  ///
  /// [_Policy.historicalTotal] is the other half of the job: every insurance
  /// and licence expense ever logged, so the caller can take them out of the
  /// per-kilometre pot they used to sit in.
  _Policy _amortisedPolicy({
    required Vehicle vehicle,
    required List<Expense> expenses,
  }) {
    var historicalTotal = 0.0;
    Expense? latestInsurance;
    Expense? latestLicense;

    for (final e in expenses) {
      switch (e.category) {
        case ExpenseCategory.insurance:
          historicalTotal += e.amount;
          if (latestInsurance == null || e.date.isAfter(latestInsurance.date)) {
            latestInsurance = e;
          }
        case ExpenseCategory.license:
          historicalTotal += e.amount;
          if (latestLicense == null || e.date.isAfter(latestLicense.date)) {
            latestLicense = e;
          }
        default:
          break;
      }
    }

    // Insurance is written annually, so the term is fixed at twelve months.
    final insuranceMonthly = latestInsurance == null
        ? 0.0
        : latestInsurance.amount / _insuranceTermMonths;

    // A licence may be issued for one year or three, and the vehicle stores
    // only the expiry date — so the term is read back from the gap between
    // paying for it and that expiry.
    final licenseMonthly = latestLicense == null
        ? 0.0
        : latestLicense.amount /
              _licenseTermMonths(
                paidOn: latestLicense.date,
                expiry: vehicle.licenseExpiry,
              );

    return _Policy(
      monthly: insuranceMonthly + licenseMonthly,
      historicalTotal: historicalTotal,
    );
  }

  /// How many months of cover a licence payment bought.
  ///
  /// Derived rather than stored: nothing in [Vehicle] records the term, but the
  /// distance from the payment to [Vehicle.licenseExpiry] implies it. That gap
  /// is snapped to whichever supported term it is closest to, so a renewal
  /// bought a few weeks early — or an expiry entered a month out — still reads
  /// as the term the driver actually paid for rather than an odd number of
  /// months. With no expiry recorded, or one that predates the payment, it
  /// falls back to a single year, which is the shorter and therefore the more
  /// cautious of the two: it never under-states what has to be set aside.
  static int _licenseTermMonths({
    required DateTime paidOn,
    required DateTime? expiry,
  }) {
    if (expiry == null) return _licenseTermMonths1Year;
    final months = _monthsBetween(paidOn, expiry);
    if (months <= 0) return _licenseTermMonths1Year;

    final toShort = (months - _licenseTermMonths1Year).abs();
    final toLong = (months - _licenseTermMonths3Year).abs();
    return toShort <= toLong
        ? _licenseTermMonths1Year
        : _licenseTermMonths3Year;
  }

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  List<_OdometerSample> _samples({
    required Vehicle vehicle,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> records,
    required List<Expense> expenses,
  }) {
    final raw =
        <_OdometerSample>[
          _OdometerSample(
            date: _dayOnly(vehicle.createdAt),
            odometer: vehicle.initialOdometer,
          ),
          for (final log in fuelLogs)
            _OdometerSample(date: _dayOnly(log.date), odometer: log.odometer),
          for (final record in records)
            _OdometerSample(
              date: _dayOnly(record.date),
              odometer: record.odometer,
            ),
          for (final expense in expenses)
            if (expense.odometer != null)
              _OdometerSample(
                date: _dayOnly(expense.date),
                odometer: expense.odometer!,
              ),
          _OdometerSample(
            date: _dayOnly(vehicle.odometerUpdatedAt ?? DateTime.now()),
            odometer: vehicle.currentOdometer,
          ),
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.odometer.compareTo(b.odometer);
        });

    // One reading per calendar day, keeping the highest odometer so a same-day
    // correction cannot invent extra kilometres.
    final unique = <_OdometerSample>[];
    for (final sample in raw) {
      if (unique.isEmpty || unique.last.date != sample.date) {
        unique.add(sample);
      } else if (sample.odometer > unique.last.odometer) {
        unique[unique.length - 1] = sample;
      }
    }
    return unique;
  }

  /// First dated reading to last, over the calendar days between them.
  double _dailyPace(List<_OdometerSample> samples) {
    if (samples.length < 2) return 0;
    final first = samples.first;
    final last = samples.last;
    return FuelMath.kmPerDay(
      distanceKm: FuelMath.distanceBetween(first.odometer, last.odometer),
      days: _daysBetween(first.date, last.date),
    );
  }

  DateTime? _projectDate(int remainingKm, double pace) {
    if (pace <= 0) return null;
    final days = (remainingKm / pace).round().clamp(
      -ProjectionLimits.horizonDays,
      ProjectionLimits.horizonDays,
    );
    return DateTime.now().add(Duration(days: days));
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysBetween(DateTime a, DateTime b) =>
      _dayOnly(b).difference(_dayOnly(a)).inDays;
}
