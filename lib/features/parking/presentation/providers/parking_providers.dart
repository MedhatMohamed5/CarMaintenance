import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/location_service.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/value_holder.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/saved_parking_location.dart';
import 'parking_repository_providers.dart';

export 'parking_repository_providers.dart';

export '../../../../core/platform/platform_providers.dart'
    show locationServiceProvider;

/// Every car's parking history, newest first.
///
/// Bound to the repository's stream on either backend, so an entry written or
/// deleted around it — a vehicle restored, another device parking — shows up
/// without a reload.
class ParkingHistoryNotifier extends Notifier<List<SavedParkingLocation>> {
  @override
  List<SavedParkingLocation> build() {
    final repository = ref.watch(parkingRepositoryProvider);
    bindStream<List<SavedParkingLocation>>(
      ref: ref,
      stream: repository.watchAll(),
      source: 'parking',
      assign: (items) => state = _sorted(items),
    );

    final items = repository.getAll();
    // Builds before the history kept the one pin in preferences. It becomes
    // the first entry, once, and is then dropped from there.
    final store = ref.read(preferencesStoreProvider);
    final legacy = SavedParkingLocation.decode(store.parkingLocation);
    if (legacy != null) {
      Future.microtask(() async {
        await repository.upsert(legacy);
        await store.setParkingLocation(null);
      });
      if (!items.any((p) => p.id == legacy.id)) {
        return _sorted([...items, legacy]);
      }
    }
    return _sorted(items);
  }

  static List<SavedParkingLocation> _sorted(List<SavedParkingLocation> items) =>
      [...items]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  Future<void> upsert(SavedParkingLocation location) async {
    await ref.read(parkingRepositoryProvider).upsert(location);
    state = _sorted([...state.where((p) => p.id != location.id), location]);
  }

  Future<void> remove(Iterable<String> ids) async {
    final repository = ref.read(parkingRepositoryProvider);
    final gone = ids.toSet();
    for (final id in gone) {
      await repository.delete(id);
    }
    state = state.where((p) => !gone.contains(p.id)).toList(growable: false);
  }
}

final parkingHistoryProvider =
    NotifierProvider<ParkingHistoryNotifier, List<SavedParkingLocation>>(
      ParkingHistoryNotifier.new,
    );

/// Where each car is parked right now: the newest unended pin per car.
///
/// All cars at once, because the move-the-car reminders are armed for every
/// car, not only the one on screen.
final activeParkingPinsProvider = Provider<List<SavedParkingLocation>>((ref) {
  final seen = <String?>{};
  return [
    for (final pin in ref.watch(parkingHistoryProvider))
      if (pin.isActive && seen.add(pin.vehicleId)) pin,
  ];
});

/// The selected car's history. Pins written before the app stored a vehicle
/// id have none, and are shown for whichever car is active, which is the only
/// reading available for them.
final vehicleParkingHistoryProvider = Provider<List<SavedParkingLocation>>((
  ref,
) {
  final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
  return [
    for (final pin in ref.watch(parkingHistoryProvider))
      if (pin.vehicleId == null || pin.vehicleId == vehicleId) pin,
  ];
});

/// The pin for the vehicle currently selected — you did not leave *this* car
/// where another one is parked.
final activeParkingProvider = Provider<SavedParkingLocation?>(
  (ref) => ref
      .watch(vehicleParkingHistoryProvider)
      .where((p) => p.isActive)
      .firstOrNull,
);

/// What went wrong the last time a pin was requested, or null.
///
/// Held here rather than thrown, because none of these are errors in the
/// programming sense — they are a conversation with the user about permissions
/// and radios, and the sheet needs to say something specific about each.
final parkingFailureProvider =
    NotifierProvider<ValueHolder<LocationFailure?>, LocationFailure?>(
      () => ValueHolder(null),
    );

/// Saves the car's current position.
///
/// Returns the pin on success and null on failure, having recorded *why* in
/// [parkingFailureProvider] so the caller can explain rather than just report
/// that nothing happened.
class ParkingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SavedParkingLocation?> pinCurrentPosition({
    String? name,
    String? note,
    String? floorOrSection,
    Duration? remindIn,
  }) async {
    ref.read(parkingFailureProvider.notifier).set(null);
    state = const AsyncLoading();

    final result = await ref.read(locationServiceProvider).current();
    if (!result.isSuccess) {
      ref.read(parkingFailureProvider.notifier).set(result.failure);
      state = const AsyncData(null);
      return null;
    }

    final now = DateTime.now();
    final location = SavedParkingLocation(
      id: 'park_${now.microsecondsSinceEpoch}',
      latitude: result.latitude,
      longitude: result.longitude,
      timestamp: now,
      name: _clean(name),
      note: _clean(note),
      floorOrSection: _clean(floorOrSection),
      vehicleId: ref.read(selectedVehicleIdOrFirstProvider),
      remindAt: remindIn == null ? null : now.add(remindIn),
      remindAfter: remindIn,
    );

    // Parking again means the car has left the last spot.
    final previous = ref.read(activeParkingProvider);
    final history = ref.read(parkingHistoryProvider.notifier);
    if (previous != null) await history.upsert(_ended(previous, now));
    await history.upsert(location);
    state = const AsyncData(null);
    return location;
  }

  /// Edits the notes on a pin without moving it.
  ///
  /// Remembering the bay number after you have already walked away is the
  /// common case, and it must not re-read GPS — by then you are somewhere else.
  Future<void> updateDetails({
    String? name,
    String? note,
    String? floorOrSection,
  }) async {
    final current = ref.read(activeParkingProvider);
    if (current == null) return;
    await updateEntry(
      current,
      name: name,
      note: note,
      floorOrSection: floorOrSection,
    );
  }

  /// Rewrites the words on any spot in the history, current or past. Where
  /// and when the car was parked stay as they were recorded.
  Future<void> updateEntry(
    SavedParkingLocation pin, {
    String? name,
    String? note,
    String? floorOrSection,
  }) async {
    await ref
        .read(parkingHistoryProvider.notifier)
        .upsert(
          pin.copyWith(
            name: _clean(name),
            note: _clean(note),
            floorOrSection: _clean(floorOrSection),
            clearName: _clean(name) == null,
            clearNote: _clean(note) == null,
            clearFloorOrSection: _clean(floorOrSection) == null,
          ),
        );
  }

  /// Sets or clears the move-the-car reminder on the pin already saved,
  /// measured from now — the driver is choosing it at the moment they tap.
  Future<void> setReminder(Duration? remindIn) async {
    final current = ref.read(activeParkingProvider);
    if (current == null) return;
    await ref
        .read(parkingHistoryProvider.notifier)
        .upsert(
          remindIn == null
              ? current.copyWith(clearRemindAt: true)
              : current.copyWith(
                  remindAt: DateTime.now().add(remindIn),
                  remindAfter: remindIn,
                ),
        );
  }

  /// The car has been found: the pin ends and stays in the history.
  Future<void> clear() async {
    ref.read(parkingFailureProvider.notifier).set(null);
    final current = ref.read(activeParkingProvider);
    if (current == null) return;
    await ref
        .read(parkingHistoryProvider.notifier)
        .upsert(_ended(current, DateTime.now()));
  }

  Future<void> delete(String id) =>
      ref.read(parkingHistoryProvider.notifier).remove([id]);

  /// Puts back an entry the driver deleted and then undid.
  Future<void> restore(SavedParkingLocation location) =>
      ref.read(parkingHistoryProvider.notifier).upsert(location);

  /// Deletes the selected car's past spots. The one it is parked in now stays:
  /// the car is still there.
  Future<void> clearHistory() =>
      ref.read(parkingHistoryProvider.notifier).remove([
        for (final pin in ref.read(vehicleParkingHistoryProvider))
          if (!pin.isActive) pin.id,
      ]);

  static SavedParkingLocation _ended(SavedParkingLocation pin, DateTime at) =>
      pin.copyWith(endedAt: at, clearRemindAt: true);

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final parkingControllerProvider =
    AsyncNotifierProvider<ParkingController, void>(ParkingController.new);
