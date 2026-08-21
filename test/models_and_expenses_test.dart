import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/features/expenses/domain/entities/expense.dart';
import 'package:vehicle_care/features/expenses/domain/usecases/summarize_expenses.dart';
import 'package:vehicle_care/features/fuel/data/models/fuel_log_model.dart';
import 'package:vehicle_care/features/fuel/domain/entities/fuel_type.dart';
import 'package:vehicle_care/features/maintenance/data/models/maintenance_record_model.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/consumable_part.dart';
import 'package:vehicle_care/features/maintenance/domain/entities/service_milestone.dart';
import 'package:vehicle_care/features/vehicles/data/models/vehicle_model.dart';

void main() {
  group('serialisation', () {
    test('vehicle survives a JSON round trip', () {
      final original = VehicleModel(
        id: 'v1',
        make: 'Toyota',
        model: 'Corolla',
        year: 2022,
        initialOdometer: 1000,
        currentOdometer: 25000,
        createdAt: DateTime(2026, 1, 15),
        nickname: 'العربية',
        licenseExpiry: DateTime(2027, 5, 1),
        partLifespanOverridesKm: const {'tires': 35000},
      );

      final decoded = VehicleModel.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(original));
      expect(decoded.partLifespanOverridesKm['tires'], 35000);
    });

    test('toFirestore drops the id and stamps updatedAt', () {
      final model = VehicleModel(
        id: 'v1',
        make: 'Kia',
        model: 'Cerato',
        year: 2021,
        initialOdometer: 0,
        currentOdometer: 100,
        createdAt: DateTime(2026, 1, 1),
      );

      final doc = model.toFirestore();
      expect(doc.containsKey('id'), isFalse);
      expect(doc['updatedAt'], isA<String>());
    });

    test('fromFirestore takes the id from the document path', () {
      final model = VehicleModel.fromFirestore(const {
        'make': 'Kia',
        'model': 'Cerato',
        'year': 2021,
        'initialOdometer': 0,
        'currentOdometer': 100,
        'createdAt': '2026-01-01T00:00:00.000',
      }, 'doc123');

      expect(model.id, 'doc123');
      expect(model.year, 2021);
    });

    test('unknown enum names fall back rather than throwing', () {
      final log = FuelLogModel.fromJson(const {
        'id': 'f1',
        'vehicleId': 'v1',
        'fuelType': 'octane98_not_a_thing',
        'liters': 40,
        'totalCost': 600,
        'odometer': 100,
      });
      expect(log.fuelType, FuelType.octane92);

      final record = MaintenanceRecordModel.fromJson(const {
        'id': 'm1',
        'vehicleId': 'v1',
        'tier': 'gigantic',
        'replacedParts': ['engineOil', 'unknown_part'],
      });
      expect(record.tier, ServiceTier.minor);
      expect(record.replacedParts.first, ConsumablePart.engineOil);
    });

    test('numeric strings coerce cleanly', () {
      final log = FuelLogModel.fromJson(const {
        'id': 'f1',
        'vehicleId': 'v1',
        'odometer': '15000',
        'liters': '42.5',
        'totalCost': '680.75',
      });
      expect(log.odometer, 15000);
      expect(log.liters, 42.5);
      expect(log.pricePerLiter, closeTo(680.75 / 42.5, 1e-9));
    });
  });

  group('SummarizeExpenses', () {
    const summarize = SummarizeExpenses();

    Expense e(double amount, ExpenseCategory category, DateTime date) =>
        Expense(
          id: '$amount$category$date',
          vehicleId: 'v1',
          date: date,
          title: 't',
          amount: amount,
          category: category,
        );

    test('empty input gives an empty summary', () {
      final summary = summarize(const []);
      expect(summary.total, 0);
      expect(summary.slices, isEmpty);
    });

    test('totals, shares and ordering', () {
      final now = DateTime.now();
      final summary = summarize([
        e(300, ExpenseCategory.repair, now),
        e(100, ExpenseCategory.wash, now),
        e(600, ExpenseCategory.repair, now),
      ]);

      expect(summary.total, 1000);
      expect(summary.slices.first.category, ExpenseCategory.repair);
      expect(summary.slices.first.total, 900);
      expect(summary.slices.first.share, closeTo(0.9, 1e-9));
      expect(summary.slices.first.count, 2);
    });

    test('this-month total excludes earlier months', () {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 2, 15);
      final summary = summarize([
        e(500, ExpenseCategory.repair, now),
        e(700, ExpenseCategory.repair, lastMonth),
      ]);

      expect(summary.total, 1200);
      expect(summary.thisMonth, 500);
      expect(summary.monthlyTotals.length, 2);
    });

    test('monthly totals are ordered oldest first', () {
      final summary = summarize([
        e(100, ExpenseCategory.wash, DateTime(2026, 3, 5)),
        e(200, ExpenseCategory.wash, DateTime(2026, 1, 5)),
      ]);
      final keys = summary.monthlyTotals.keys.toList();
      expect(keys.first.month, 1);
      expect(keys.last.month, 3);
    });
  });
}
