import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_loader.dart';
import 'file_opener.dart';
import 'file_saver.dart';
import 'image_source_picker.dart';
import 'location_service.dart';

final fileSaverProvider = Provider<FileSaver>((ref) => createFileSaver());

final fileOpenerProvider = Provider<FileOpener>((ref) => createFileOpener());

final fileLoaderProvider = Provider<FileLoader>((ref) => createFileLoader());

/// Reads the device's position.
///
/// **Core, not the parking feature.** It started there because parking was the
/// only caller; the workshop location picker is the second, and a core widget
/// reaching into a feature's provider file would have inverted the dependency.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => PlatformImagePicker(),
);
