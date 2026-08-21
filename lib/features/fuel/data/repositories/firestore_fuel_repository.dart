import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/repositories/fuel_repository.dart';
import '../models/fuel_log_model.dart';

class FirestoreFuelRepository implements FuelRepository {
  FirestoreFuelRepository(this._paths) {
    _subscription = _paths.fuelLogs.snapshots().listen(
      (snapshot) => _cache = snapshot.docs
          .map((d) => FuelLogModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;
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
  Future<void> upsert(FuelLog log) => _paths.fuelLogs
      .doc(log.id)
      .set(FuelLogModel.fromEntity(log).toFirestore());

  @override
  Future<void> delete(String id) => _paths.fuelLogs.doc(id).delete();

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    final snapshot = await _paths.fuelLogs
        .where('vehicleId', isEqualTo: vehicleId)
        .get();
    final batch = FirebaseBootstrap.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> dispose() => _subscription.cancel();
}
