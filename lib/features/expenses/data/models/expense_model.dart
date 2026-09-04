import '../../../../core/utils/json_x.dart';
import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.vehicleId,
    required super.date,
    required super.title,
    required super.amount,
    required super.category,
    super.odometer,
    super.notes,
    super.invoiceAttachments,
  });

  factory ExpenseModel.fromEntity(Expense e) => ExpenseModel(
    id: e.id,
    vehicleId: e.vehicleId,
    date: e.date,
    title: e.title,
    amount: e.amount,
    category: e.category,
    odometer: e.odometer,
    notes: e.notes,
    invoiceAttachments: e.invoiceAttachments,
  );

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String? ?? '',
    date: JsonX.dateOr(json['date'], DateTime.now()),
    title: json['title'] as String? ?? '',
    amount: JsonX.doubleOr(json['amount'], 0),
    category: ExpenseCategory.fromName(json['category'] as String?),
    odometer: json['odometer'] == null
        ? null
        : JsonX.intOr(json['odometer'], 0),
    notes: json['notes'] as String?,
    // Reads the list, and falls back to the single `invoiceBase64` a
    // record written before multiple attachments existed would carry.
    // Without this an already-attached receipt would silently disappear on
    // the first read after the upgrade.
    invoiceAttachments: JsonX.stringListOrSingle(
      json['invoiceAttachments'] ?? json['invoiceBase64'],
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toIso8601String(),
    'title': title,
    'amount': amount,
    'category': category.name,
    'odometer': odometer,
    'notes': notes,
    'invoiceAttachments': invoiceAttachments,
  };

  factory ExpenseModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => ExpenseModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
