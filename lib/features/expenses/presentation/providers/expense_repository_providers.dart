import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/backend_providers.dart';
import '../../data/datasources/expense_local_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../data/repositories/firestore_expense_repository.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/summarize_expenses.dart';

final expenseLocalDataSourceProvider = Provider<ExpenseLocalDataSource>(
  (ref) => ExpenseLocalDataSource(),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreExpenseRepository(
      ref.watch(firestorePathsProvider),
      mirror: ExpenseRepositoryImpl(ref.watch(expenseLocalDataSourceProvider)),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return ExpenseRepositoryImpl(ref.watch(expenseLocalDataSourceProvider));
});

final summarizeExpensesProvider = Provider<SummarizeExpenses>(
  (ref) => const SummarizeExpenses(),
);
