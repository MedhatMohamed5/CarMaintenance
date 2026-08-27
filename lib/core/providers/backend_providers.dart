import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../firebase/firebase_bootstrap.dart';
import 'app_providers.dart';

/// Whether reads and writes go through Firestore.
///
/// **Being signed in is the whole condition.** This used to also require a
/// "data source" setting the driver had to find and flip, which asked them to
/// answer a question they have no way to reason about — and let someone create
/// an account and then quietly keep writing to a tree no other device can
/// reach. Sync is not a preference; it is what having an account *means*.
///
/// Signing out drops back to local for the same reason: with no account, the
/// workspace would fall back to this device's generated id, and syncing to a
/// tree only this phone can find is not syncing.
///
/// Offline is not a case this has to handle. `cloud_firestore` is initialised
/// with persistence enabled, so it serves reads from its local cache and queues
/// writes until the connection returns. This decides *where data belongs*, not
/// whether the network happens to be up.
final isRemoteBackendProvider = Provider<bool>(
  (ref) => ref.watch(isSignedInProvider),
);

/// The key everything in the cloud is filed under.
///
/// **The signed-in user's id, when there is one.** This used to be a UUID
/// generated once per device and kept in preferences, which is why data could
/// never appear on a second device even with Firebase configured: each install
/// minted its own id and wrote to its own tree, so the two never met. Keying on
/// the account is what makes the same history reachable from a phone and a
/// browser.
///
/// The generated id survives as the fallback for a signed-out install, so a
/// driver who has been using the app local-only keeps their data exactly where
/// it already is. Signing in moves them onto their account's tree; it does not
/// migrate what was there before, which is a separate decision and a separate
/// piece of work.
final workspaceIdProvider = Provider<String>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId != null) return userId;

  final prefs = ref.watch(preferencesStoreProvider);
  final existing = prefs.workspaceId;
  if (existing != null) return existing;
  final generated = ref.read(uuidProvider).v4();
  prefs.setWorkspaceId(generated);
  return generated;
});

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseBootstrap.firestore,
);

final firestorePathsProvider = Provider<FirestorePaths>(
  (ref) => FirestorePaths(
    ref.watch(workspaceIdProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);
