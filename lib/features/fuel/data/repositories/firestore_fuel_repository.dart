import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/repositories/fuel_repository.dart';
import '../models/fuel_log_model.dart';
import '../../../../core/firebase/offline_write.dart';

class FirestoreFuelRepository implements FuelRepository {
  FirestoreFuelRepository(this._paths, {FuelRepository? mirror})
    : _mirror = mirror {
    _subscription = _paths.fuelLogs.snapshots().listen(
      (snapshot) => _cache = snapshot.docs
          .map((d) => FuelLogModel.fromFirestore(d.data(), d.id))
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
  final FuelRepository? _mirror;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  List<FuelLog> _cache = const [];

  static List<FuelLog> _forVehicle(List<FuelLog> all, String vehicleId) {
    final list = all.where((l) => l.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.odometer.compareTo(a.odometer));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<FuelLog>> watchByVehicle(String vehicleId) => _paths.fuelLogs
      .where('vehicleId', isEqualTo: vehicleId)
      .orderBy('odometer', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => FuelLogModel.fromFirestore(d.data(), d.id))
            .toList(growable: false),
      );

  @override
  List<FuelLog> getByVehicle(String vehicleId) =>
      _forVehicle(_cache, vehicleId);

  @override
  Future<void> upsert(FuelLog log) async {
    await _mirror?.upsert(log);
    return fireAndForget(
      _paths.fuelLogs
          .doc(log.id)
          .set(FuelLogModel.fromEntity(log).toFirestore()),
      label: 'fuel ${log.id}',
    );
  }

  @override
  Future<void> delete(String id) async {
    await _mirror?.delete(id);
    return fireAndForget(
      _paths.fuelLogs.doc(id).delete(),
      label: 'delete fuel $id',
    );
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    final snapshot = await _paths.fuelLogs
        .where('vehicleId', isEqualTo: vehicleId)
        .get();
    final batch = _paths.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> dispose() => _subscription.cancel();
}
