import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/features/fuel/domain/entities/fuel_log.dart';
import 'package:vehicle_care/features/fuel/domain/entities/fuel_type.dart';
import 'package:vehicle_care/features/fuel/domain/usecases/calculate_fuel_stats.dart';

FuelLog log({
  required int odometer,
  required double liters,
  required double cost,
  bool full = true,
  FuelType type = FuelType.octane92,
  int dayOffset = 0,
}) => FuelLog(
  id: 'log_$odometer',
  vehicleId: 'v1',
  date: DateTime(2026, 1, 1).add(Duration(days: dayOffset)),
  odometer: odometer,
  liters: liters,
  fuelType: type,
  totalCost: cost,
  isFullTank: full,
);

void main() {
  const calc = CalculateFuelStats();

  test('returns empty stats with no logs', () {
    final stats = calc(const []);
    expect(stats.hasEfficiencyData, isFalse);
    expect(stats.totalCost, 0);
  });

  test('a single fill cannot measure consumption', () {
    final stats = calc([log(odometer: 10000, liters: 40, cost: 600)]);
    expect(stats.segments, isEmpty);
    expect(stats.totalLiters, 40);
    expect(stats.totalCost, 600);
  });

  test('measures full-to-full efficiency and cost per km', () {
    final stats = calc([
      log(odometer: 10000, liters: 40, cost: 600),
      log(odometer: 10400, liters: 40, cost: 640, dayOffset: 10),
    ]);

    expect(stats.segments, hasLength(1));
    final segment = stats.segments.single;
    expect(segment.distanceKm, 400);
    expect(segment.litersUsed, 40);
    expect(segment.efficiency, 10);
    expect(segment.costPerKm, closeTo(1.6, 1e-9));
    expect(segment.litersPer100Km, 10);
  });

  test('a partial fill extends the segment rather than breaking it', () {
    final stats = calc([
      log(odometer: 10000, liters: 40, cost: 600),
      log(odometer: 10200, liters: 20, cost: 300, full: false, dayOffset: 5),
      log(odometer: 10600, liters: 40, cost: 600, dayOffset: 10),
    ]);

    expect(stats.segments, hasLength(1));
    final segment = stats.segments.single;
    // 600 km covered on the 60 L poured in after the first full tank.
    expect(segment.distanceKm, 600);
    expect(segment.litersUsed, 60);
    expect(segment.efficiency, 10);
  });

  test('average is weighted by distance, not a mean of ratios', () {
    final stats = calc([
      log(odometer: 0, liters: 40, cost: 600),
      // 800 km at 20 km/L
      log(odometer: 800, liters: 40, cost: 600, dayOffset: 10),
      // 40 km at 8 km/L
      log(odometer: 840, liters: 5, cost: 75, dayOffset: 12),
    ]);

    expect(stats.segments, hasLength(2));
    // Weighted: 840 km / 45 L = 18.67, not the 14 a naive mean would give.
    expect(stats.avgEfficiency, closeTo(840 / 45, 1e-9));
  });

  test('ignores duplicate odometer readings instead of dividing by zero', () {
    final stats = calc([
      log(odometer: 10000, liters: 40, cost: 600),
      log(odometer: 10000, liters: 10, cost: 150, dayOffset: 1),
    ]);
    expect(stats.segments, isEmpty);
    expect(stats.avgEfficiency, 0);
  });

  test('groups measured segments by the grade that was burned', () {
    final stats = calc([
      log(odometer: 0, liters: 40, cost: 600),
      log(
        odometer: 400,
        liters: 40,
        cost: 640,
        type: FuelType.octane92,
        dayOffset: 10,
      ),
      log(
        odometer: 900,
        liters: 40,
        cost: 720,
        type: FuelType.octane95,
        dayOffset: 20,
      ),
    ]);

    expect(stats.byFuelType, hasLength(2));
    // Sorted best-efficiency first.
    expect(stats.byFuelType.first.fuelType, FuelType.octane95);
    expect(stats.byFuelType.first.avgEfficiency, closeTo(500 / 40, 1e-9));
  });

  test('derives a daily pace from the odometer trail', () {
    final stats = calc([
      log(odometer: 0, liters: 40, cost: 600),
      log(odometer: 1000, liters: 40, cost: 600, dayOffset: 20),
    ]);
    expect(stats.avgDailyKm, closeTo(50, 1e-9));
  });

  test('orders by odometer even when dates arrive out of sequence', () {
    final stats = calc([
      log(odometer: 10400, liters: 40, cost: 640, dayOffset: 10),
      log(odometer: 10000, liters: 40, cost: 600, dayOffset: 20),
    ]);
    expect(stats.segments, hasLength(1));
    expect(stats.segments.single.distanceKm, 400);
  });
}
