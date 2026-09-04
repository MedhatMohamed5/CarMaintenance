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
import '../../../../core/firebase/offline_write.dart';

class FirestoreMaintenanceRepository implements MaintenanceRepository {
  FirestoreMaintenanceRepository(
    this._paths, {
    Uuid? uuid,
    MaintenanceRepository? mirror,
  }) : _uuid = uuid ?? const Uuid(),
       _mirror = mirror {
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
  final MaintenanceRepository? _mirror;
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
    await _mirror?.saveService(record);
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

    // Only a service that actually happened resets a part.
    //
    // **A booking must not.** The parts on an appointment are what the driver
    // expects to have fitted next month, and deriving replacements from them
    // would zero every one of those health bars today — the app would show a
    // car as freshly serviced because someone wrote down that they intended to
    // service it. The stale sweep above still runs unconditionally, so editing
    // a completed entry back into a booking withdraws the resets it made.
    final derived = <PartReplacementModel>[];
    for (final part
        in record.isCompleted
            ? record.replacedParts
            : const <ConsumablePart>[]) {
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

    // Not awaited: a batch commit, like any Firestore write, stays pending
    // until the server acknowledges it, and offline that never comes. The
    // caches below are updated immediately so the UI is correct either way.
    await fireAndForget(batch.commit(), label: 'service ${record.id}');

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
    await _mirror?.deleteRecord(id);
    final batch = _paths.firestore.batch()..delete(_paths.maintenance.doc(id));

    final linked = await _paths.partReplacements
        .where('maintenanceRecordId', isEqualTo: id)
        .get();
    for (final doc in linked.docs) {
      batch.delete(doc.reference);
    }

    await fireAndForget(batch.commit(), label: 'delete service $id');
  }

  @override
  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
    DateTime? date,
    double? cost,
    String? notes,
  }) async {
    await _mirror?.resetPart(
      vehicleId: vehicleId,
      part: part,
      odometer: odometer,
      date: date,
      cost: cost,
      notes: notes,
    );
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
    return fireAndForget(
      _paths.partReplacements.doc(id).set(model.toFirestore()),
      label: 'reset part $id',
    );
  }

  @override
  Future<void> upsertReplacement(PartReplacement replacement) async {
    await _mirror?.upsertReplacement(replacement);
    final model = PartReplacementModel.fromEntity(replacement);
    _replacementCache = [
      ..._replacementCache.where((r) => r.id != replacement.id),
      model,
    ];
    return fireAndForget(
      _paths.partReplacements.doc(replacement.id).set(model.toFirestore()),
      label: 'replacement ${replacement.id}',
    );
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
