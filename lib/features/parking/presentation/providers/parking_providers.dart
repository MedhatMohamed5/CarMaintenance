import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/location_service.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/saved_parking_location.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// The saved pin, or null when the driver has none.
///
/// Synchronous and seeded from the store in `build()`, like every other
/// notifier here — the pin is one small string in preferences, so there is
/// nothing to wait for and no loading state for the dashboard to render.
class ParkingNotifier extends Notifier<SavedParkingLocation?> {
  @override
  SavedParkingLocation? build() => SavedParkingLocation.decode(
    ref.watch(preferencesStoreProvider).parkingLocation,
  );

  Future<void> save(SavedParkingLocation location) async {
    state = location;
    await ref
        .read(preferencesStoreProvider)
        .setParkingLocation(location.encode());
  }

  Future<void> clear() async {
    state = null;
    await ref.read(preferencesStoreProvider).setParkingLocation(null);
  }
}

final parkingLocationProvider =
    NotifierProvider<ParkingNotifier, SavedParkingLocation?>(
      ParkingNotifier.new,
    );

/// The pin for the vehicle currently selected.
///
/// A pin saved for one car should not surface while another is active — you
/// did not leave *this* car there. Records written before the app stored a
/// vehicle id have none, and are shown for whichever car is active, which is
/// the only reading available for them.
final activeParkingProvider = Provider<SavedParkingLocation?>((ref) {
  final saved = ref.watch(parkingLocationProvider);
  if (saved == null) return null;
  if (saved.vehicleId == null) return saved;
  return saved.vehicleId == ref.watch(selectedVehicleIdOrFirstProvider)
      ? saved
      : null;
});

/// What went wrong the last time a pin was requested, or null.
///
/// Held here rather than thrown, because none of these are errors in the
/// programming sense — they are a conversation with the user about permissions
/// and radios, and the sheet needs to say something specific about each.
final parkingFailureProvider = StateProvider<LocationFailure?>((ref) => null);

/// Saves the car's current position.
///
/// Returns the pin on success and null on failure, having recorded *why* in
/// [parkingFailureProvider] so the caller can explain rather than just report
/// that nothing happened.
class ParkingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SavedParkingLocation?> pinCurrentPosition({
    String? note,
    String? floorOrSection,
  }) async {
    ref.read(parkingFailureProvider.notifier).state = null;
    state = const AsyncLoading();

    final result = await ref.read(locationServiceProvider).current();
    if (!result.isSuccess) {
      ref.read(parkingFailureProvider.notifier).state = result.failure;
      state = const AsyncData(null);
      return null;
    }

    final now = DateTime.now();
    final location = SavedParkingLocation(
      id: 'park_${now.microsecondsSinceEpoch}',
      latitude: result.latitude,
      longitude: result.longitude,
      timestamp: now,
      note: _clean(note),
      floorOrSection: _clean(floorOrSection),
      vehicleId: ref.read(selectedVehicleIdOrFirstProvider),
    );

    await ref.read(parkingLocationProvider.notifier).save(location);
    state = const AsyncData(null);
    return location;
  }

  /// Edits the notes on a pin without moving it.
  ///
  /// Remembering the bay number after you have already walked away is the
  /// common case, and it must not re-read GPS — by then you are somewhere else.
  Future<void> updateDetails({String? note, String? floorOrSection}) async {
    final current = ref.read(parkingLocationProvider);
    if (current == null) return;

    await ref
        .read(parkingLocationProvider.notifier)
        .save(
          current.copyWith(
            note: _clean(note),
            floorOrSection: _clean(floorOrSection),
            clearNote: _clean(note) == null,
            clearFloorOrSection: _clean(floorOrSection) == null,
          ),
        );
  }

  Future<void> clear() async {
    ref.read(parkingFailureProvider.notifier).state = null;
    await ref.read(parkingLocationProvider.notifier).clear();
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final parkingControllerProvider =
    AsyncNotifierProvider<ParkingController, void>(ParkingController.new);
