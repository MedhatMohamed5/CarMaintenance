import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../models/vehicle_model.dart';

class FirestoreVehicleRepository implements VehicleRepository {
  FirestoreVehicleRepository(this._paths) {
    _subscription = _paths.vehicles.snapshots().listen(
      (snapshot) => _cache = _fromSnapshot(snapshot),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  List<Vehicle> _cache = const [];

  List<Vehicle> _fromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final items = snapshot.docs
        .map((d) => VehicleModel.fromFirestore(d.data(), d.id))
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<Vehicle>.unmodifiable(items);
  }

  @override
  Stream<List<Vehicle>> watchVehicles() =>
      _paths.vehicles.snapshots().map(_fromSnapshot);

  @override
  List<Vehicle> getVehicles() => _cache;

  @override
  Vehicle? getById(String id) => _cache.where((v) => v.id == id).firstOrNull;

  @override
  Future<void> upsert(Vehicle vehicle) => _paths.vehicles
      .doc(vehicle.id)
      .set(VehicleModel.fromEntity(vehicle).toFirestore());

  @override
  Future<void> delete(String id) => _paths.vehicles.doc(id).delete();

  @override
  Future<void> updateOdometer(String vehicleId, int odometer) async {
    final current = getById(vehicleId);
    if (current == null || odometer <= current.currentOdometer) return;
    await upsert(
      current.copyWith(
        currentOdometer: odometer,
        odometerUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> dispose() => _subscription.cancel();
}
