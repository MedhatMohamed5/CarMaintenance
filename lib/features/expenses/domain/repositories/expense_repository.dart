import '../entities/expense.dart';

abstract interface class ExpenseRepository {
  /// Newest first.
  Stream<List<Expense>> watchByVehicle(String vehicleId);

  List<Expense> getByVehicle(String vehicleId);

  Future<void> upsert(Expense expense);

  Future<void> delete(String id);

  Future<void> deleteForVehicle(String vehicleId);
}
