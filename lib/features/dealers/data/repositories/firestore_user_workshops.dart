import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../domain/entities/dealer.dart';
import '../models/dealer_model.dart';

/// The workshops the driver added, in their account.
///
/// **Only what they added.** The standard directory is admin-defined, identical
/// for everyone and already reachable without an account, so copying forty rows
/// into every workspace would pay storage and bandwidth to duplicate what
/// Remote Config serves for free. What is genuinely per-account is the short
/// list they created — and that is exactly what should follow them to a second
/// device.
class FirestoreUserWorkshops {
  const FirestoreUserWorkshops(this._paths);

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
