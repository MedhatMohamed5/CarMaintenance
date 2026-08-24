import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._paths) {
    _subscription = _paths.expenses.snapshots().listen(
      (snapshot) => _cache = snapshot.docs
          .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  List<Expense> _cache = const [];

  static List<Expense> _forVehicle(List<Expense> all, String vehicleId) {
    final list = all.where((e) => e.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<Expense>> watchByVehicle(String vehicleId) => _paths.expenses
      .where('vehicleId', isEqualTo: vehicleId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
            .toList(growable: false),
      );

  @override
  List<Expense> getByVehicle(String vehicleId) =>
      _forVehicle(_cache, vehicleId);

  @override
  Future<void> upsert(Expense expense) => _paths.expenses
      .doc(expense.id)
      .set(ExpenseModel.fromEntity(expense).toFirestore());

  @override
  Future<void> delete(String id) => _paths.expenses.doc(id).delete();

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    final snapshot = await _paths.expenses
        .where('vehicleId', isEqualTo: vehicleId)
        .get();
    final batch = _paths.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> dispose() => _subscription.cancel();
}
