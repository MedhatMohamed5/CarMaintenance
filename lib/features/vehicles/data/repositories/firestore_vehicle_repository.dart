import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../models/vehicle_model.dart';
import '../../../../core/firebase/offline_write.dart';

class FirestoreVehicleRepository implements VehicleRepository {
  FirestoreVehicleRepository(this._paths, {VehicleRepository? mirror})
    : _mirror = mirror {
    _subscription = _paths.vehicles.snapshots().listen(
      (snapshot) => _cache = _fromSnapshot(snapshot),
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
  final VehicleRepository? _mirror;
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
  Future<void> upsert(Vehicle vehicle) async {
    // Local first, and awaited: it is fast, it cannot fail for want of a
    // network, and it is what the app falls back to when signed out.
    await _mirror?.upsert(vehicle);
    return fireAndForget(
      _paths.vehicles
          .doc(vehicle.id)
          .set(VehicleModel.fromEntity(vehicle).toFirestore()),
      label: 'vehicle ${vehicle.id}',
    );
  }

  @override
  Future<void> delete(String id) async {
    await _mirror?.delete(id);
    return fireAndForget(
      _paths.vehicles.doc(id).delete(),
      label: 'delete vehicle $id',
    );
  }

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
