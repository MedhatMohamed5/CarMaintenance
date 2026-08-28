import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/vehicle_note.dart';
import 'note_repository_providers.dart';

export 'note_repository_providers.dart';

class NotesNotifier extends Notifier<List<VehicleNote>> {
  @override
  List<VehicleNote> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(noteRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<VehicleNote>>(
        ref: ref,
        stream: repository.watchByVehicle(vehicleId),
        assign: (items) => state = _sorted(items),
      );
    }

    return _sorted(repository.getByVehicle(vehicleId));
  }

  static List<VehicleNote> _sorted(List<VehicleNote> items) =>
      [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> upsert(VehicleNote note) async {
    await ref.read(noteRepositoryProvider).upsert(note);
    state = _sorted([...state.where((n) => n.id != note.id), note]);
  }

  Future<void> remove(String id) async {
    await ref.read(noteRepositoryProvider).delete(id);
    state = state.where((n) => n.id != id).toList(growable: false);
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<VehicleNote>>(
  NotesNotifier.new,
);

/// Open (not yet done) notes, newest first — what the dashboard card and the
/// quick-action badge both read.
final openNotesProvider = Provider<List<VehicleNote>>(
  (ref) => ref.watch(notesProvider).where((n) => !n.isDone).toList(),
);

class NoteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> add(String text) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    final trimmed = text.trim();
    if (vehicleId == null || trimmed.isEmpty) return false;

    return _run(
      () => ref
          .read(notesProvider.notifier)
          .upsert(
            VehicleNote(
              id: ref.read(uuidProvider).v4(),
              vehicleId: vehicleId,
              text: trimmed,
              createdAt: DateTime.now(),
            ),
          ),
    );
  }

  Future<bool> save(VehicleNote note) =>
      _run(() => ref.read(notesProvider.notifier).upsert(note));

  Future<bool> toggleDone(VehicleNote note) => save(note.toggleDone());

  Future<bool> remove(String id) =>
      _run(() => ref.read(notesProvider.notifier).remove(id));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final noteControllerProvider = AsyncNotifierProvider<NoteController, void>(
  NoteController.new,
);
