import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../domain/entities/saved_parking_location.dart';
import '../../domain/repositories/parking_repository.dart';

class FirestoreParkingRepository implements ParkingRepository {
  FirestoreParkingRepository(this._paths, {ParkingRepository? mirror})
    : _mirror = mirror {
    _subscription = _paths.parking.snapshots().listen(
      (snapshot) => _cache = _read(snapshot),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;

  /// The on-device store, kept in step with every write — see
  /// `FirestoreExpenseRepository` for why this mirroring exists.
  final ParkingRepository? _mirror;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  List<SavedParkingLocation> _cache = const [];

  static List<SavedParkingLocation> _read(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map((d) => SavedParkingLocation.fromJson({...d.data(), 'id': d.id}))
      .nonNulls
      .toList(growable: false);

  static Map<String, dynamic> _toFirestore(SavedParkingLocation location) => {
    ...location.toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  @override
  Stream<List<SavedParkingLocation>> watchAll() =>
      _paths.parking.snapshots().map(_read);

  @override
  List<SavedParkingLocation> getAll() => _cache;

  @override
  Future<void> upsert(SavedParkingLocation location) async {
    await _mirror?.upsert(location);
    return fireAndForget(
      _paths.parking.doc(location.id).set(_toFirestore(location)),
      label: 'parking ${location.id}',
    );
  }

  @override
  Future<void> delete(String id) async {
    await _mirror?.delete(id);
    return fireAndForget(
      _paths.parking.doc(id).delete(),
      label: 'delete parking $id',
    );
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    await _mirror?.deleteForVehicle(vehicleId);
    final snapshot = await _paths.parking
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
