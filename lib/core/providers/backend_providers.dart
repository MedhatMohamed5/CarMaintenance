import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_bootstrap.dart';
import 'app_providers.dart';

class BackendModeNotifier extends Notifier<BackendMode> {
  @override
  BackendMode build() {
    final stored = BackendMode.fromName(
      ref.read(preferencesStoreProvider).backendMode,
    );
    return stored == BackendMode.firestore && !FirebaseBootstrap.isAvailable
        ? BackendMode.local
        : stored;
  }

  Future<bool> set(BackendMode mode) async {
    if (mode == BackendMode.firestore) {
      final ready = await FirebaseBootstrap.tryInitialize();
      if (!ready) return false;
    }
    state = mode;
    await ref.read(preferencesStoreProvider).setBackendMode(mode.name);
    return true;
  }
}

final backendModeProvider = NotifierProvider<BackendModeNotifier, BackendMode>(
  BackendModeNotifier.new,
);

final isRemoteBackendProvider = Provider<bool>(
  (ref) => ref.watch(backendModeProvider) == BackendMode.firestore,
);

final workspaceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(preferencesStoreProvider);
  final existing = prefs.workspaceId;
  if (existing != null) return existing;
  final generated = ref.read(uuidProvider).v4();
  prefs.setWorkspaceId(generated);
  return generated;
});

final firestorePathsProvider = Provider<FirestorePaths>(
  (ref) => FirestorePaths(ref.watch(workspaceIdProvider)),
);
