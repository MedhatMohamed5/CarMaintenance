import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../fuel/domain/fuel_math.dart';
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

  /// Re-reads this vehicle's expenses in place, for writes that went straight
  /// to the repository — a bulk import, say. Preferred over `ref.invalidate`,
  /// which tears the provider down mid-cascade.
  void reload() {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return;
    state = _sorted(
      ref.read(expenseRepositoryProvider).getByVehicle(vehicleId),
    );
  }

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

/// Everything the car has cost, split by where the money went, measured
/// against the distance it was driven under the app's watch.
///
/// The four streams are disjoint by construction, so nothing is counted
/// twice:
///   * [fuel]    every fill logged, partial or full;
///   * [service] one entry per periodic phase, de-duplicated by milestone;
///   * [parts]   consumables fitted *outside* a service, whose price is not
///               already inside a service record;
///   * [other]   free-form expenses (insurance, fines, accessories).
class TotalCostOfOwnership {
  const TotalCostOfOwnership({
    required this.fuel,
    required this.service,
    required this.parts,
    required this.other,
    required this.trackedDistanceKm,
  });

  const TotalCostOfOwnership.empty()
    : fuel = 0,
      service = 0,
      parts = 0,
      other = 0,
      trackedDistanceKm = 0;

  final double fuel;
  final double service;
  final double parts;
  final double other;

  /// `currentOdometer - initialOdometer`, never negative.
  final int trackedDistanceKm;

  /// `fuel + service + parts + other`.
  double get total => fuel + service + parts + other;

  /// `total / trackedDistanceKm`, or `0.0` when the car has not moved since it
  /// joined the app — a divide by zero would read as `Infinity`, and a
  /// near-zero distance would read as a spend per kilometre nobody believes.
  double get costPerKm =>
      FuelMath.costPerKm(totalCost: total, distanceKm: trackedDistanceKm);

  /// Per-kilometre breakdown, so a caller can say "fuel is 1.90 of the 3.40".
  double get fuelPerKm => _rate(fuel);
  double get servicePerKm => _rate(service);
  double get partsPerKm => _rate(parts);
  double get otherPerKm => _rate(other);

  /// Whether the cost per kilometre is meaningful yet.
  bool get hasDistance => trackedDistanceKm > 0;

  bool get isEmpty => total <= 0;

  double _rate(double amount) =>
      FuelMath.costPerKm(totalCost: amount, distanceKm: trackedDistanceKm);
}

/// The single source of truth for what the vehicle has cost.
///
/// Recomputes on every fuel, service, part and expense write, and — because
/// the distance baseline reads the vehicle's live odometer — on every master
/// odometer update too, so the cost per kilometre falls as the car is driven
/// rather than only when money is spent.
final totalCostProvider = Provider<TotalCostOfOwnership>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const TotalCostOfOwnership.empty();

  return TotalCostOfOwnership(
    fuel: ref.watch(fuelStatsProvider).totalCost,
    // De-duplicated: a milestone logged twice must not be billed twice.
    service: ref.watch(serviceSpendProvider),
    // Standalone only: parts fitted during a service are already in `service`.
    parts: ref.watch(partsSpendProvider),
    other: ref.watch(expenseSummaryProvider).total,
    trackedDistanceKm: vehicle.trackedDistanceKm,
  );
});

/// True operational cost per kilometre. Zero, never `NaN` or `Infinity`, until
/// the odometer has actually moved past its starting reading.
final overallCostPerKmProvider = Provider<double>(
  (ref) => ref.watch(totalCostProvider).costPerKm,
);

/// The ownership delta the cost per kilometre is measured over:
/// `currentOdometer - initialOdometer`, floored at zero.
final trackedDistanceProvider = Provider<int>(
  (ref) => ref.watch(totalCostProvider).trackedDistanceKm,
);

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
    List<String> invoiceAttachments = const [],
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
              invoiceAttachments: invoiceAttachments,
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

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, void>(ExpenseController.new);
