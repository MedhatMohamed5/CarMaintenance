import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';
import '../../../../core/firebase/offline_write.dart';

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._paths, {ExpenseRepository? mirror})
    : _mirror = mirror {
    _subscription = _paths.expenses.snapshots().listen(
      (snapshot) => _cache = snapshot.docs
          .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;

  /// The on-device store, kept in step with every write.
  ///
  /// **Signing out must not roll a driver back.** Reads come from Firestore
  /// while signed in, so without this the local copy froze at whatever it held
  /// when they signed in — edit for a week, sign out, and the week is gone from
  /// view. Mirroring every write means the local store is always a complete,
  /// current copy, which is also what makes signing out safe and the app
  /// genuinely offline-first rather than cloud-only-when-logged-in.
  ///
  /// Null when there is nothing to mirror to, which is the case during the
  /// sign-in migration: it constructs cloud repositories on their own.
  final ExpenseRepository? _mirror;
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
  Future<void> upsert(Expense expense) async {
    await _mirror?.upsert(expense);
    return fireAndForget(
      _paths.expenses
          .doc(expense.id)
          .set(ExpenseModel.fromEntity(expense).toFirestore()),
      label: 'expense ${expense.id}',
    );
  }

  @override
  Future<void> delete(String id) async {
    await _mirror?.delete(id);
    return fireAndForget(
      _paths.expenses.doc(id).delete(),
      label: 'delete expense $id',
    );
  }

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
