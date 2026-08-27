import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/data/repositories/firestore_expense_repository.dart';
import '../../features/expenses/presentation/providers/expense_repository_providers.dart';
import '../../features/fuel/data/repositories/firestore_fuel_repository.dart';
import '../../features/fuel/data/repositories/fuel_repository_impl.dart';
import '../../features/fuel/presentation/providers/fuel_repository_providers.dart';
import '../../features/maintenance/data/repositories/firestore_maintenance_repository.dart';
import '../../features/maintenance/data/repositories/maintenance_repository_impl.dart';
import '../../features/maintenance/presentation/providers/maintenance_repository_providers.dart';
import '../../features/vehicles/data/repositories/firestore_vehicle_repository.dart';
import '../../features/vehicles/data/repositories/vehicle_repository_impl.dart';
import '../../features/vehicles/presentation/providers/vehicle_providers.dart';
import '../auth/auth_providers.dart';
import '../providers/backend_providers.dart';
import 'local_data_migrator.dart';

/// A migrator wired to **both** sides at once.
///
/// The feature repository providers return local *or* cloud depending on
/// `isRemoteBackendProvider`, which is exactly what a migration cannot use: it
/// needs to read the local store and write the cloud one in the same breath.
/// Both are constructed explicitly here rather than going through those
/// providers.
final localDataMigratorProvider = Provider<LocalDataMigrator>((ref) {
  final paths = ref.watch(firestorePathsProvider);

  final cloudVehicles = FirestoreVehicleRepository(paths);
  final cloudFuel = FirestoreFuelRepository(paths);
  final cloudMaintenance = FirestoreMaintenanceRepository(paths);
  final cloudExpenses = FirestoreExpenseRepository(paths);

  // Each Firestore repository opens a snapshot listener in its constructor;
  // without this they would outlive the migration and keep the account's
  // collections subscribed for the life of the app.
  ref.onDispose(() {
    cloudVehicles.dispose();
    cloudFuel.dispose();
    cloudMaintenance.dispose();
    cloudExpenses.dispose();
  });

  return LocalDataMigrator(
    localVehicles: VehicleRepositoryImpl(
      ref.watch(vehicleLocalDataSourceProvider),
    ),
    localFuel: FuelRepositoryImpl(ref.watch(fuelLocalDataSourceProvider)),
    localMaintenance: MaintenanceRepositoryImpl(
      ref.watch(maintenanceLocalDataSourceProvider),
    ),
    localExpenses: ExpenseRepositoryImpl(
      ref.watch(expenseLocalDataSourceProvider),
    ),
    cloudVehicles: cloudVehicles,
    cloudFuel: cloudFuel,
    cloudMaintenance: cloudMaintenance,
    cloudExpenses: cloudExpenses,
  );
});

/// Offers the local history to the account whenever that account is empty.
///
/// **No stored "already done" flag.** One was tried and was wrong: deleting the
/// cloud copy left the flag saying done, so the next sign-in skipped the
/// upload and the app showed an empty garage while the local data sat beside it
/// untouched. Whether the account holds anything is a question with a live
/// answer, and asking it cannot go stale.
class MigrationController extends AsyncNotifier<MigrationResult?> {
  @override
  Future<MigrationResult?> build() async => null;

  Future<MigrationResult?> migrateIfNeeded() async {
    if (ref.read(currentUserIdProvider) == null) return null;

    state = const AsyncLoading();
    final result = await ref.read(localDataMigratorProvider).run();
    state = AsyncData(result);
    return result;
  }
}

final migrationControllerProvider =
    AsyncNotifierProvider<MigrationController, MigrationResult?>(
      MigrationController.new,
    );
