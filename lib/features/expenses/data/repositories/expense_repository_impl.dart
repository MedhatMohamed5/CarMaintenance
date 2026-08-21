import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_local_datasource.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._local);

  final ExpenseLocalDataSource _local;

  List<Expense> _forVehicle(List<ExpenseModel> all, String vehicleId) {
    final list = all.where((e) => e.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Stream<List<Expense>> watchByVehicle(String vehicleId) =>
      _local.watchAll().map((all) => _forVehicle(all, vehicleId));

  @override
  List<Expense> getByVehicle(String vehicleId) =>
      _forVehicle(_local.readAll(), vehicleId);

  @override
  Future<void> upsert(Expense expense) =>
      _local.put(ExpenseModel.fromEntity(expense));

  @override
  Future<void> delete(String id) => _local.delete(id);

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    for (final e in _local.readAll().where((e) => e.vehicleId == vehicleId)) {
      await _local.delete(e.id);
    }
  }
}
