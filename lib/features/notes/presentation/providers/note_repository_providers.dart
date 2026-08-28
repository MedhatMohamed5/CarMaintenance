import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/backend_providers.dart';
import '../../data/datasources/note_local_datasource.dart';
import '../../data/repositories/firestore_note_repository.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../domain/repositories/note_repository.dart';

final noteLocalDataSourceProvider = Provider<NoteLocalDataSource>(
  (ref) => NoteLocalDataSource(),
);

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreNoteRepository(
      ref.watch(firestorePathsProvider),
      mirror: NoteRepositoryImpl(ref.watch(noteLocalDataSourceProvider)),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return NoteRepositoryImpl(ref.watch(noteLocalDataSourceProvider));
});
