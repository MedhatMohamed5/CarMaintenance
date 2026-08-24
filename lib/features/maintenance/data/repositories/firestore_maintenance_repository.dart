import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/part_replacement.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../models/maintenance_record_model.dart';
import '../models/part_replacement_model.dart';

class FirestoreMaintenanceRepository implements MaintenanceRepository {
  FirestoreMaintenanceRepository(this._paths, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid() {
    _recordsSub = _paths.maintenance.snapshots().listen(
      (s) => _recordCache = s.docs
          .map((d) => MaintenanceRecordModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
    _replacementsSub = _paths.partReplacements.snapshots().listen(
      (s) => _replacementCache = s.docs
          .map((d) => PartReplacementModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;
  final Uuid _uuid;

  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _recordsSub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _replacementsSub;

  List<MaintenanceRecord> _recordCache = const [];
  List<PartReplacement> _replacementCache = const [];

  static List<T> _sortedByOdometer<T>(
    List<T> items,
    String vehicleId,
    String Function(T) vehicleIdOf,
    int Function(T) odometerOf,
  ) {
    final list = items.where((i) => vehicleIdOf(i) == vehicleId).toList();
    list.sort((a, b) => odometerOf(b).compareTo(odometerOf(a)));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<MaintenanceRecord>> watchRecords(String vehicleId) => _paths
      .maintenance
      .where('vehicleId', isEqualTo: vehicleId)
      .orderBy('odometer', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => MaintenanceRecordModel.fromFirestore(d.data(), d.id))
            .toList(growable: false),
      );

  @override
  List<MaintenanceRecord> getRecords(String vehicleId) => _sortedByOdometer(
    _recordCache,
    vehicleId,
    (r) => r.vehicleId,
    (r) => r.odometer,
  );

  @override
  MaintenanceRecord? findByPhase(String vehicleId, int phase) {
    MaintenanceRecord? found;
    for (final r in getRecords(vehicleId)) {
      if (r.resolvedMilestonePhase != phase) continue;
      if (found == null || r.date.isAfter(found.date)) found = r;
    }
    return found;
  }

  @override
  Stream<List<PartReplacement>> watchReplacements(String vehicleId) => _paths
      .partReplacements
      .where('vehicleId', isEqualTo: vehicleId)
      .orderBy('odometer', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PartReplacementModel.fromFirestore(d.data(), d.id))
            .toList(growable: false),
      );

  @override
  List<PartReplacement> getReplacements(String vehicleId) => _sortedByOdometer(
    _replacementCache,
    vehicleId,
    (r) => r.vehicleId,
    (r) => r.odometer,
  );

  @override
  Future<void> saveService(MaintenanceRecord record) async {
    final batch = _paths.firestore.batch();

    batch.set(
      _paths.maintenance.doc(record.id),
      MaintenanceRecordModel.fromEntity(record).toFirestore(),
    );

    final stale = await _paths.partReplacements
        .where('maintenanceRecordId', isEqualTo: record.id)
        .get();
    for (final doc in stale.docs) {
      batch.delete(doc.reference);
    }

    final derived = <PartReplacementModel>[];
    for (final part in record.replacedParts) {
      final id = _uuid.v4();
      final model = PartReplacementModel(
        id: id,
        vehicleId: record.vehicleId,
        part: part,
        odometer: record.odometer,
        date: record.date,
        maintenanceRecordId: record.id,
      );
      derived.add(model);
      batch.set(_paths.partReplacements.doc(id), model.toFirestore());
    }

    await batch.commit();

    _recordCache = [
      ..._recordCache.where((r) => r.id != record.id),
      MaintenanceRecordModel.fromEntity(record),
    ];
    _replacementCache = [
      ..._replacementCache.where((r) => r.maintenanceRecordId != record.id),
      ...derived,
    ];
  }

  @override
  Future<void> deleteRecord(String id) async {
    final batch = _paths.firestore.batch()..delete(_paths.maintenance.doc(id));

    final linked = await _paths.partReplacements
        .where('maintenanceRecordId', isEqualTo: id)
        .get();
    for (final doc in linked.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
    DateTime? date,
    double? cost,
    String? notes,
  }) {
    final id = _uuid.v4();
    final model = PartReplacementModel(
      id: id,
      vehicleId: vehicleId,
      part: part,
      odometer: odometer,
      date: date ?? DateTime.now(),
      cost: cost,
      notes: notes,
    );
    _replacementCache = [..._replacementCache, model];
    return _paths.partReplacements.doc(id).set(model.toFirestore());
  }

  @override
  Future<void> upsertReplacement(PartReplacement replacement) {
    final model = PartReplacementModel.fromEntity(replacement);
    _replacementCache = [
      ..._replacementCache.where((r) => r.id != replacement.id),
      model,
    ];
    return _paths.partReplacements.doc(replacement.id).set(model.toFirestore());
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    final batch = _paths.firestore.batch();

    for (final collection in [_paths.maintenance, _paths.partReplacements]) {
      final snapshot = await collection
          .where('vehicleId', isEqualTo: vehicleId)
          .get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  Future<void> dispose() async {
    await _recordsSub.cancel();
    await _replacementsSub.cancel();
  }
}
