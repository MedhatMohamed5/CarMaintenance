import 'package:geolocator/geolocator.dart';

/// Why a location request did not produce a fix.
///
/// Named causes rather than a bare null, because each one needs a different
/// sentence from the app: a denied permission can be asked for again, a
/// permanently denied one has to be changed in Settings, and a disabled GPS
/// radio is not about permissions at all. Collapsing them into "failed" is what
/// makes a feature feel broken when it is merely waiting on the user.
enum LocationFailure {
  /// The device's location services are switched off entirely.
  serviceDisabled,

  /// The user said no this time; asking again is legitimate.
  denied,

  /// The user said never. Only the system settings screen can undo it.
  deniedForever,

  /// A fix was requested but none arrived — indoors, underground, or timed out.
  unavailable,
}

/// A coordinate pair, or the reason there isn't one.
class LocationResult {
  const LocationResult.success(this.latitude, this.longitude) : failure = null;

  const LocationResult.failed(this.failure) : latitude = 0, longitude = 0;

  final double latitude;
  final double longitude;
  final LocationFailure? failure;

  bool get isSuccess => failure == null;
}

/// Reads the device's position.
///
/// An interface rather than a direct `Geolocator` call so the feature can be
/// exercised without a GPS radio, and so the plugin stays behind one seam — it
/// is the only native dependency this feature adds.
abstract interface class LocationService {
  Future<LocationResult> current();

  /// Opens the OS screen where a permanently denied permission can be granted.
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// A garage roof or a basement will not give a precise fix, and waiting for
  /// one there means waiting forever. Medium accuracy with a short ceiling
  /// gets a usable pin in the places people actually park.
  static const Duration _timeout = Duration(seconds: 12);

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationFailure.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeout,
        ),
      );
      return LocationResult.success(position.latitude, position.longitude);
    } on Object {
      // Timeouts, a radio that answers with nothing, a platform channel that
      // is not there on desktop — all of them mean the same thing to the
      // driver, and none of them should take the app down.
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } on Object {
      // Nothing useful to do if the OS will not open its own settings.
    }
  }
}
