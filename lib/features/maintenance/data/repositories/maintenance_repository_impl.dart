import 'package:uuid/uuid.dart';

import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/part_replacement.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../datasources/maintenance_local_datasource.dart';
import '../models/maintenance_record_model.dart';
import '../models/part_replacement_model.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._local, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final MaintenanceLocalDataSource _local;
  final Uuid _uuid;

  List<MaintenanceRecord> _records(String vehicleId) {
    final list = _local.records
        .readAll()
        .where((r) => r.vehicleId == vehicleId)
        .toList();
    list.sort((a, b) => b.odometer.compareTo(a.odometer));
    return list;
  }

  List<PartReplacement> _replacements(String vehicleId) {
    final list = _local.replacements
        .readAll()
        .where((r) => r.vehicleId == vehicleId)
        .toList();
    list.sort((a, b) => b.odometer.compareTo(a.odometer));
    return list;
  }

  @override
  Stream<List<MaintenanceRecord>> watchRecords(String vehicleId) =>
      _local.records.watchAll().map((_) => _records(vehicleId));

  @override
  List<MaintenanceRecord> getRecords(String vehicleId) => _records(vehicleId);

  @override
  MaintenanceRecord? findByPhase(String vehicleId, int phase) {
    MaintenanceRecord? found;
    for (final r in _records(vehicleId)) {
      if (r.resolvedMilestonePhase != phase) continue;
      if (found == null || r.date.isAfter(found.date)) found = r;
    }
    return found;
  }

  @override
  Stream<List<PartReplacement>> watchReplacements(String vehicleId) =>
      _local.replacements.watchAll().map((_) => _replacements(vehicleId));

  @override
  List<PartReplacement> getReplacements(String vehicleId) =>
      _replacements(vehicleId);

  @override
  Future<void> saveService(MaintenanceRecord record) async {
    await _local.records.put(MaintenanceRecordModel.fromEntity(record));

    // Re-derive this service's replacements rather than appending, so editing
    // a service (removing a part from it) cannot leave a stale reset behind.
    final stale = _local.replacements.readAll().where(
      (r) => r.maintenanceRecordId == record.id,
    );
    for (final r in stale) {
      await _local.replacements.delete(r.id);
    }

    await _local.replacements.putAll(
      record.replacedParts.map(
        (part) => PartReplacementModel(
          id: _uuid.v4(),
          vehicleId: record.vehicleId,
          part: part,
          odometer: record.odometer,
          date: record.date,
          maintenanceRecordId: record.id,
        ),
      ),
    );
  }

  @override
  Future<void> deleteRecord(String id) async {
    await _local.records.delete(id);
    final linked = _local.replacements.readAll().where(
      (r) => r.maintenanceRecordId == id,
    );
    for (final r in linked) {
      await _local.replacements.delete(r.id);
    }
  }

  @override
  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
    DateTime? date,
    double? cost,
    String? notes,
  }) => _local.replacements.put(
    PartReplacementModel(
      id: _uuid.v4(),
      vehicleId: vehicleId,
      part: part,
      odometer: odometer,
      date: date ?? DateTime.now(),
      cost: cost,
      notes: notes,
    ),
  );

  @override
  Future<void> upsertReplacement(PartReplacement replacement) =>
      _local.replacements.put(PartReplacementModel.fromEntity(replacement));

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    for (final r in _local.records.readAll().where(
      (r) => r.vehicleId == vehicleId,
    )) {
      await _local.records.delete(r.id);
    }
    for (final r in _local.replacements.readAll().where(
      (r) => r.vehicleId == vehicleId,
    )) {
      await _local.replacements.delete(r.id);
    }
  }
}
