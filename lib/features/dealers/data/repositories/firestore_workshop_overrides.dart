import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../domain/entities/dealer.dart';
import '../models/dealer_model.dart';

/// The driver's own workshops, in their account.
///
/// **Only what they own.** The published directory is shared, identical for
/// everyone and already reachable without an account, so copying forty rows
/// into every workspace would be paying storage and bandwidth to duplicate a
/// document the app fetches anyway. What is genuinely per-account is the short
/// list of workshops they added and the published rows they corrected — and
/// that list is exactly what should follow them to a second device.
///
/// Not a `DealerRepository`. It answers a narrower question than that interface
/// asks — no search, no sorting, no ratings — and implementing the whole thing
/// to satisfy three methods would invite callers to reach for the wrong one.
class FirestoreWorkshopOverrides {
  const FirestoreWorkshopOverrides(this._paths);

  final FirestorePaths _paths;

  /// Everything this account has stored, or an empty list if the read fails.
  ///
  /// Failure is not distinguished from empty on purpose: the caller merges what
  /// comes back into a local store that is already complete and usable, so
  /// there is nothing for it to do differently either way.
  Future<List<Dealer>> fetchAll() async {
    try {
      final snapshot = await _paths.workshops.get();
      return [
        for (final doc in snapshot.docs)
          DealerModel.fromFirestore(doc.data(), doc.id),
      ];
    } on Object {
      return const [];
    }
  }

  /// Writes one row, without waiting for the server — see [fireAndForget]. The
  /// local store is the copy the UI reads, and it is already updated by the
  /// time this is called.
  Future<void> put(Dealer dealer) => fireAndForget(
    _paths.workshops
        .doc(dealer.id)
        .set(DealerModel.fromEntity(dealer).toFirestore()),
    label: 'workshop ${dealer.id}',
  );

  Future<void> delete(String id) => fireAndForget(
    _paths.workshops.doc(id).delete(),
    label: 'delete workshop $id',
  );
}
