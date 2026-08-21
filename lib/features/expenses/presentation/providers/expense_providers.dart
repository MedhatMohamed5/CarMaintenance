import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/summarize_expenses.dart';
import 'expense_repository_providers.dart';

export 'expense_repository_providers.dart';

class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(expenseRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<Expense>>(
        ref: ref,
        stream: repository.watchByVehicle(vehicleId),
        assign: (items) => state = _sorted(items),
      );
    }

    return _sorted(repository.getByVehicle(vehicleId));
  }

  static List<Expense> _sorted(List<Expense> items) =>
      [...items]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> upsert(Expense expense) async {
    await ref.read(expenseRepositoryProvider).upsert(expense);
    state = _sorted([...state.where((e) => e.id != expense.id), expense]);
  }

  Future<void> remove(String id) async {
    await ref.read(expenseRepositoryProvider).delete(id);
    state = state.where((e) => e.id != id).toList(growable: false);
  }
}

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(
  ExpensesNotifier.new,
);

final expenseSummaryProvider = Provider<ExpenseSummary>(
  (ref) => ref.watch(summarizeExpensesProvider)(ref.watch(expensesProvider)),
);

final expenseFilterProvider = StateProvider<ExpenseCategory?>((ref) => null);

final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final all = ref.watch(expensesProvider);
  final filter = ref.watch(expenseFilterProvider);
  if (filter == null) return all;
  return all.where((e) => e.category == filter).toList(growable: false);
});

class TotalCostOfOwnership {
  const TotalCostOfOwnership({
    required this.fuel,
    required this.service,
    required this.other,
  });

  final double fuel;
  final double service;
  final double other;

  double get total => fuel + service + other;
}

final totalCostProvider = Provider<TotalCostOfOwnership>((ref) {
  return TotalCostOfOwnership(
    fuel: ref.watch(fuelStatsProvider).totalCost,
    // De-duplicated: a milestone logged twice must not be billed twice.
    service: ref.watch(serviceSpendProvider),
    other: ref.watch(expenseSummaryProvider).total,
  );
});

final overallCostPerKmProvider = Provider<double>((ref) {
  final distance = ref.watch(selectedVehicleProvider)?.trackedDistanceKm ?? 0;
  if (distance <= 0) return 0;
  return ref.watch(totalCostProvider).total / distance;
});

class ExpenseController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> add({
    required DateTime date,
    required String title,
    required double amount,
    required ExpenseCategory category,
    int? odometer,
    String? notes,
  }) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return false;

    return _run(
      () => ref
          .read(expensesProvider.notifier)
          .upsert(
            Expense(
              id: ref.read(uuidProvider).v4(),
              vehicleId: vehicleId,
              date: date,
              title: title.trim(),
              amount: amount,
              category: category,
              odometer: odometer,
              notes: notes,
            ),
          ),
    );
  }

  Future<bool> save(Expense expense) =>
      _run(() => ref.read(expensesProvider.notifier).upsert(expense));

  Future<bool> remove(String id) =>
      _run(() => ref.read(expensesProvider.notifier).remove(id));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final expenseControllerProvider = AsyncNotifierProvider<ExpenseController, void>(
  ExpenseController.new,
);
