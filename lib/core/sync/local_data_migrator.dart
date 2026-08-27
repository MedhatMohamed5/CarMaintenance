import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/fuel/domain/repositories/fuel_repository.dart';
import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';

/// What a migration moved, so the app can say something specific afterwards.
class MigrationResult {
  const MigrationResult({
    this.vehicles = 0,
    this.fuelLogs = 0,
    this.services = 0,
    this.partReplacements = 0,
    this.expenses = 0,
    this.failed = false,
    this.conflicts = 0,
  });

  final int vehicles;
  final int fuelLogs;
  final int services;
  final int partReplacements;
  final int expenses;

  /// True when something went wrong part-way. The local copy is never deleted,
  /// so a failed run leaves the driver exactly where they started.
  final bool failed;

  /// Records this device and the account both hold, with different contents.
  ///
  /// **Left as the account's version, and counted so the driver can be told.**
  /// Deciding which copy is newer would need an `updatedAt` on every entity,
  /// and there is none: `date` is when the fill-up happened, not when the row
  /// was last edited. Guessing would silently destroy whichever edit lost, so
  /// nothing is overwritten and the disagreement is reported instead.
  final int conflicts;

  int get total => vehicles + fuelLogs + services + partReplacements + expenses;

  bool get movedAnything => total > 0;
}

/// Copies everything held locally into the account the user just signed into.
///
/// **Why this exists.** The app is usable without an account: a driver can log
/// fuel and services for months on one device. The moment they sign in, that
/// history has to follow them, or signing in reads as losing their data.
///
/// **Additive, and it runs on every sign-in.** An earlier version stored a
/// "this account has been migrated" flag and skipped forever after, which broke
/// the moment the cloud copy went away: the flag still said done while the
/// account held nothing, and the app faithfully showed an empty garage with the
/// local copy sitting untouched beside it. A later version asked whether the
/// cloud was empty, which was better but still skipped the case that actually
/// bites — signing out, adding a few fill-ups, and signing back in to find them
/// nowhere.
///
/// So: every record the account does not already have is uploaded, every time.
/// A record it *does* have is never overwritten, because the copy in the
/// account may hold edits from another device and this one has no way to know
/// which is newer — see [MigrationResult.conflicts].
///
/// Every entity carries a stable id and the Firestore repositories write to
/// `.doc(entity.id)`, so a repeated pass cannot duplicate anything.
///
/// **Nothing local is deleted.** A migration that half-succeeded on a flaky
/// connection would otherwise take the only copy with it. The local store stays
/// as it is, and the flag that records "this account has been migrated" is only
/// written after a clean pass.
class LocalDataMigrator {
  const LocalDataMigrator({
    required VehicleRepository localVehicles,
    required FuelRepository localFuel,
    required MaintenanceRepository localMaintenance,
    required ExpenseRepository localExpenses,
    required VehicleRepository cloudVehicles,
    required FuelRepository cloudFuel,
    required MaintenanceRepository cloudMaintenance,
    required ExpenseRepository cloudExpenses,
  }) : _localVehicles = localVehicles,
       _localFuel = localFuel,
       _localMaintenance = localMaintenance,
       _localExpenses = localExpenses,
       _cloudVehicles = cloudVehicles,
       _cloudFuel = cloudFuel,
       _cloudMaintenance = cloudMaintenance,
       _cloudExpenses = cloudExpenses;

  final VehicleRepository _localVehicles;
  final FuelRepository _localFuel;
  final MaintenanceRepository _localMaintenance;
  final ExpenseRepository _localExpenses;

  final VehicleRepository _cloudVehicles;
  final FuelRepository _cloudFuel;
  final MaintenanceRepository _cloudMaintenance;
  final ExpenseRepository _cloudExpenses;

  Future<MigrationResult> run() async {
    try {
      final vehicles = _localVehicles.getVehicles();
      if (vehicles.isEmpty) return const MigrationResult();

      // Read the account before writing to it. `getVehicles` on the Firestore
      // repository serves its snapshot cache, which is empty until the first
      // snapshot lands, so the collections are queried directly instead.
      final cloudVehicles = await _cloudVehicles.watchVehicles().first;
      var conflicts = 0;

      var uploadedVehicles = 0;
      for (final vehicle in vehicles) {
        final existing = cloudVehicles
            .where((v) => v.id == vehicle.id)
            .firstOrNull;
        if (existing == null) {
          await _cloudVehicles.upsert(vehicle);
          uploadedVehicles++;
        } else if (existing != vehicle) {
          conflicts++;
        }
      }

      var fuelLogs = 0;
      var services = 0;
      var replacements = 0;
      var expenses = 0;

      for (final vehicle in vehicles) {
        final cloudFuel = await _cloudFuel.watchByVehicle(vehicle.id).first;
        for (final log in _localFuel.getByVehicle(vehicle.id)) {
          final existing = cloudFuel.where((l) => l.id == log.id).firstOrNull;
          if (existing == null) {
            await _cloudFuel.upsert(log);
            fuelLogs++;
          } else if (existing != log) {
            conflicts++;
          }
        }

        final cloudRecords = await _cloudMaintenance
            .watchRecords(vehicle.id)
            .first;
        for (final record in _localMaintenance.getRecords(vehicle.id)) {
          final existing = cloudRecords
              .where((r) => r.id == record.id)
              .firstOrNull;
          if (existing == null) {
            await _cloudMaintenance.saveService(record);
            services++;
          } else if (existing != record) {
            conflicts++;
          }
        }

        final cloudParts = await _cloudMaintenance
            .watchReplacements(vehicle.id)
            .first;
        for (final part in _localMaintenance.getReplacements(vehicle.id)) {
          final existing = cloudParts.where((r) => r.id == part.id).firstOrNull;
          if (existing == null) {
            await _cloudMaintenance.upsertReplacement(part);
            replacements++;
          } else if (existing != part) {
            conflicts++;
          }
        }

        final cloudExpenses = await _cloudExpenses
            .watchByVehicle(vehicle.id)
            .first;
        for (final expense in _localExpenses.getByVehicle(vehicle.id)) {
          final existing = cloudExpenses
              .where((e) => e.id == expense.id)
              .firstOrNull;
          if (existing == null) {
            await _cloudExpenses.upsert(expense);
            expenses++;
          } else if (existing != expense) {
            conflicts++;
          }
        }
      }

      return MigrationResult(
        vehicles: uploadedVehicles,
        fuelLogs: fuelLogs,
        services: services,
        partReplacements: replacements,
        expenses: expenses,
        conflicts: conflicts,
      );
    } on Object {
      // Reported, never thrown. A failed merge must not block the sign-in that
      // triggered it: the user is signed in, their local data is intact, and
      // the next sign-in tries again.
      return const MigrationResult(failed: true);
    }
  }
}
