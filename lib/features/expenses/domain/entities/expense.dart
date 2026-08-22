import 'package:equatable/equatable.dart';

/// Cost buckets outside fuel and scheduled service.
enum ExpenseCategory {
  repair(l10nKey: 'catRepair', colorValue: 0xFFF87171, iconKey: 'build'),
  accessories(
    l10nKey: 'catAccessories',
    colorValue: 0xFFA78BFA,
    iconKey: 'star',
  ),
  parking(l10nKey: 'catParking', colorValue: 0xFF38BDF8, iconKey: 'parking'),
  fines(l10nKey: 'catFines', colorValue: 0xFFFB923C, iconKey: 'gavel'),
  wash(l10nKey: 'catWash', colorValue: 0xFF22D3EE, iconKey: 'wash'),
  tolls(l10nKey: 'catTolls', colorValue: 0xFF818CF8, iconKey: 'road'),
  insurance(l10nKey: 'catInsurance', colorValue: 0xFF34D399, iconKey: 'shield'),
  license(l10nKey: 'catLicense', colorValue: 0xFFF472B6, iconKey: 'doc'),
  other(l10nKey: 'catOther', colorValue: 0xFF9A9AA6, iconKey: 'more');

  const ExpenseCategory({
    required this.l10nKey,
    required this.colorValue,
    required this.iconKey,
  });

  final String l10nKey;
  final int colorValue;
  final String iconKey;

  static ExpenseCategory fromName(String? name) => ExpenseCategory.values
      .firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.other);
}

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.title,
    required this.amount,
    required this.category,
    this.odometer,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final int? odometer;
  final String? notes;

  Expense copyWith({
    DateTime? date,
    String? title,
    double? amount,
    ExpenseCategory? category,
    int? odometer,
    String? notes,
  }) => Expense(
    id: id,
    vehicleId: vehicleId,
    date: date ?? this.date,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    odometer: odometer ?? this.odometer,
    notes: notes ?? this.notes,
  );

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    date,
    title,
    amount,
    category,
    odometer,
    notes,
  ];
}

/// One slice of the expenses breakdown chart.
class ExpenseSlice extends Equatable {
  const ExpenseSlice({
    required this.category,
    required this.total,
    required this.count,
    required this.share,
  });

  final ExpenseCategory category;
  final double total;
  final int count;

  /// 0..1 of the grand total.
  final double share;

  @override
  List<Object?> get props => [category, total, count, share];
}
