import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../domain/entities/vehicle_note.dart';
import '../../domain/repositories/note_repository.dart';
import '../models/vehicle_note_model.dart';

class FirestoreNoteRepository implements NoteRepository {
  FirestoreNoteRepository(this._paths, {NoteRepository? mirror})
    : _mirror = mirror {
    _subscription = _paths.notes.snapshots().listen(
      (snapshot) => _cache = snapshot.docs
          .map((d) => VehicleNoteModel.fromFirestore(d.data(), d.id))
          .toList(growable: false),
      onError: (_) {},
    );
  }

  final FirestorePaths _paths;

  /// The on-device store, kept in step with every write — see
  /// `FirestoreExpenseRepository` for why this mirroring exists.
  final NoteRepository? _mirror;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  List<VehicleNote> _cache = const [];

  static List<VehicleNote> _forVehicle(
    List<VehicleNote> all,
    String vehicleId,
  ) {
    final list = all.where((n) => n.vehicleId == vehicleId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<VehicleNote>> watchByVehicle(String vehicleId) => _paths.notes
      .where('vehicleId', isEqualTo: vehicleId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => VehicleNoteModel.fromFirestore(d.data(), d.id))
            .toList(growable: false),
      );

  @override
  List<VehicleNote> getByVehicle(String vehicleId) =>
      _forVehicle(_cache, vehicleId);

  @override
  Future<void> upsert(VehicleNote note) async {
    await _mirror?.upsert(note);
    return fireAndForget(
      _paths.notes
          .doc(note.id)
          .set(VehicleNoteModel.fromEntity(note).toFirestore()),
      label: 'note ${note.id}',
    );
  }

  @override
  Future<void> delete(String id) async {
    await _mirror?.delete(id);
    return fireAndForget(
      _paths.notes.doc(id).delete(),
      label: 'delete note $id',
    );
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    final snapshot = await _paths.notes
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
