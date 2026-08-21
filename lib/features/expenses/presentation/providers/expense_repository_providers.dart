import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/expense_local_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/summarize_expenses.dart';

final expenseLocalDataSourceProvider = Provider<ExpenseLocalDataSource>(
  (ref) => ExpenseLocalDataSource(),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepositoryImpl(ref.watch(expenseLocalDataSourceProvider)),
);

final summarizeExpensesProvider = Provider<SummarizeExpenses>(
  (ref) => const SummarizeExpenses(),
);
