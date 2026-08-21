import '../../../../core/storage/hive_boxes.dart';
import '../../../../core/storage/json_box.dart';
import '../models/expense_model.dart';

class ExpenseLocalDataSource {
  ExpenseLocalDataSource()
    : _box = JsonBox<ExpenseModel>(
        boxName: HiveBoxes.expenses,
        fromJson: ExpenseModel.fromJson,
        toJson: (v) => v.toJson(),
        idOf: (v) => v.id,
      );

  final JsonBox<ExpenseModel> _box;

  Stream<List<ExpenseModel>> watchAll() => _box.watchAll();

  List<ExpenseModel> readAll() => _box.readAll();

  Future<void> put(ExpenseModel model) => _box.put(model);

  Future<void> delete(String id) => _box.delete(id);
}
