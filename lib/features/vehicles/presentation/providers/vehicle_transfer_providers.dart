import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/file_saver.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/domain/entities/part_replacement.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../data/vehicle_bundle_remapper.dart';
import '../../data/vehicle_transfer_json_codec.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_transfer_bundle.dart';
import '../../domain/repositories/vehicle_transfer_codec.dart';
import 'vehicle_providers.dart';

export '../../domain/repositories/vehicle_transfer_codec.dart';

final vehicleTransferCodecProvider = Provider<VehicleTransferCodec>(
  (ref) => const VehicleTransferJsonCodec(),
);

final vehicleBundleRemapperProvider = Provider<VehicleBundleRemapper>(
  (ref) => const VehicleBundleRemapper(),
);

/// What a finished transfer produced, so the UI can report specifics rather
/// than a bare "done".
sealed class VehicleTransferOutcome {
  const VehicleTransferOutcome();
}

class VehicleExportedOutcome extends VehicleTransferOutcome {
  const VehicleExportedOutcome({required this.file, required this.entryCount});

  final SavedFile file;
  final int entryCount;
}

class VehicleImportedOutcome extends VehicleTransferOutcome {
  const VehicleImportedOutcome({
    required this.vehicleName,
    required this.entryCount,
  });

  final String vehicleName;
  final int entryCount;
}

/// Moves one vehicle and everything it owns in or out of a JSON file.
///
/// Both directions go through the repositories rather than the Hive boxes, so
/// an import lands in whichever backend is active and a cloud user does not
/// end up with a vehicle only their device can see.
class VehicleTransferController extends AsyncNotifier<VehicleTransferOutcome?> {
  @override
  Future<VehicleTransferOutcome?> build() async => null;

  /// Collects [vehicle]'s profile, service history, fuel and expenses into one
  /// document and hands it to the platform's save path.
  Future<bool> exportVehicle(Vehicle vehicle) => _run(() async {
    final maintenance = ref.read(maintenanceRepositoryProvider);
    final bundle = VehicleTransferBundle(
      vehicle: vehicle,
      records: maintenance.getRecords(vehicle.id),
      replacements: maintenance.getReplacements(vehicle.id),
      fuelLogs: ref.read(fuelRepositoryProvider).getByVehicle(vehicle.id),
      expenses: ref.read(expenseRepositoryProvider).getByVehicle(vehicle.id),
      fuelPriceDefaults: ref.read(defaultFuelPricesProvider),
    );

    final codec = ref.read(vehicleTransferCodecProvider);
    final file = await ref
        .read(fileSaverProvider)
        .save(
          fileName: codec.fileNameFor(vehicle),
          bytes: codec.encode(bundle),
          mimeType: codec.mimeType,
        );

    return VehicleExportedOutcome(file: file, entryCount: bundle.entryCount);
  });

  /// Prompts for a document and restores it as a **new** vehicle.
  ///
  /// Returns true on a successful import and on a cancelled picker alike —
  /// dismissing the picker is a normal outcome, and leaves the outcome null so
  /// the UI stays quiet.
  Future<bool> importVehicle() => _run(() async {
    final codec = ref.read(vehicleTransferCodecProvider);
    final picked = await ref
        .read(fileLoaderProvider)
        .pick(extensions: codec.extensions);
    if (picked == null) return null;

    final bundle = ref.read(vehicleBundleRemapperProvider)(
      codec.decode(picked.bytes),
      newId: ref.read(uuidProvider).v4,
    );

    await _write(bundle);
    await ref
        .read(defaultFuelPricesProvider.notifier)
        .merge(bundle.fuelPriceDefaults);

    return VehicleImportedOutcome(
      vehicleName: bundle.vehicle.displayName,
      entryCount: bundle.entryCount,
    );
  });

  Future<void> _write(VehicleTransferBundle bundle) async {
    final vehicleId = bundle.vehicle.id;
    await ref.read(vehiclesProvider.notifier).upsert(bundle.vehicle);

    final maintenance = ref.read(maintenanceRepositoryProvider);
    for (final record in bundle.records) {
      await maintenance.saveService(record);
    }

    final derived = maintenance.getReplacements(vehicleId);
    for (final imported in bundle.replacements) {
      if (imported.maintenanceRecordId == null) {
        await maintenance.upsertReplacement(imported);
        continue;
      }
      PartReplacement? match;
      for (final written in derived) {
        if (written.maintenanceRecordId == imported.maintenanceRecordId &&
            written.part == imported.part) {
          match = written;
          break;
        }
      }
      if (match == null) continue;
      if (imported.cost == null &&
          (imported.notes == null || imported.notes!.isEmpty)) {
        continue;
      }
      await maintenance.upsertReplacement(
        PartReplacement(
          id: match.id,
          vehicleId: match.vehicleId,
          part: match.part,
          odometer: imported.odometer,
          date: imported.date,
          cost: imported.cost,
          notes: imported.notes,
          maintenanceRecordId: match.maintenanceRecordId,
        ),
      );
    }

    final fuel = ref.read(fuelRepositoryProvider);
    for (final log in bundle.fuelLogs) {
      await fuel.upsert(log);
    }

    final expenses = ref.read(expenseRepositoryProvider);
    for (final expense in bundle.expenses) {
      await expenses.upsert(expense);
    }

    // Switching to the imported vehicle is both the useful landing spot and
    // what re-seeds every per-vehicle list provider; the explicit reloads
    // below cover the case where it was already the selected vehicle.
    await ref.read(selectedVehicleIdProvider.notifier).select(vehicleId);
    ref.read(vehiclesProvider.notifier).reload();
    ref.read(maintenanceRecordsProvider.notifier).reload();
    ref.read(partReplacementsProvider.notifier).reload();
    ref.read(fuelLogsProvider.notifier).reload();
    ref.read(expensesProvider.notifier).reload();
  }

  Future<bool> _run(Future<VehicleTransferOutcome?> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final vehicleTransferControllerProvider =
    AsyncNotifierProvider<VehicleTransferController, VehicleTransferOutcome?>(
      VehicleTransferController.new,
    );
