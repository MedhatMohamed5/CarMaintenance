import 'package:equatable/equatable.dart';

/// Operational cost buckets: what running the car costs that is not fuel and
/// not work done to the car.
///
/// **Mechanical work no longer belongs here.** A repair is a service — it
/// happens at a workshop, at an odometer reading, and it fits parts whose wear
/// has to be reset — so it is logged as `ServiceTier.corrective` and priced
/// with the rest of the maintenance. What stays is licensing, fines, parking,
/// washing, tolls and insurance: money the car costs without anyone touching
/// it.
enum ExpenseCategory {
  /// Kept only so rows written before repairs became a service tier still
  /// parse and still show their real category. **Not offered on the form** —
  /// see [pickable] — and counted as repair spend rather than operational
  /// spend everywhere money is split.
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

  /// Work done to the car, which this feature no longer accepts.
  bool get isMechanical => this == ExpenseCategory.repair;

  /// What the form offers.
  ///
  /// [current] is included even when it is not operational, so opening an
  /// expense saved before the split does not silently re-categorise it the
  /// moment its sheet is built.
  static List<ExpenseCategory> pickable([ExpenseCategory? current]) => [
    for (final c in ExpenseCategory.values)
      if (!c.isMechanical || c == current) c,
  ];

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
    this.invoiceAttachments = const [],
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final int? odometer;
  final String? notes;

  /// Invoices or receipts photographed for this entry, base64-encoded.
  ///
  /// A list rather than one string because a service is regularly billed on
  /// more than one document — parts on one, labour on another — and the driver
  /// who has both should not have to choose.
  ///
  /// Inline rather than a file path or a bucket URL, matching the vehicle
  /// photo: a record stays one self-contained thing that exports, syncs and
  /// deletes without leaving an orphan behind. That is also why the count and
  /// the per-file size are capped where they are picked — see
  /// `InvoiceAttachmentField` — because the whole record has to fit inside
  /// Firestore's 1 MB document limit.
  final List<String> invoiceAttachments;

  Expense copyWith({
    DateTime? date,
    String? title,
    double? amount,
    ExpenseCategory? category,
    int? odometer,
    String? notes,

    /// No `clear` flag needed, unlike the nullable field this replaced: an
    /// empty list is a value in its own right, so removing the last attachment
    /// is just another `copyWith`.
    List<String>? invoiceAttachments,
  }) => Expense(
    id: id,
    vehicleId: vehicleId,
    date: date ?? this.date,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    odometer: odometer ?? this.odometer,
    notes: notes ?? this.notes,
    invoiceAttachments: invoiceAttachments ?? this.invoiceAttachments,
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
    invoiceAttachments,
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
