import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_saver.dart';
import 'image_source_picker.dart';
import 'link_launcher.dart';

final fileSaverProvider = Provider<FileSaver>((ref) => createFileSaver());

final linkLauncherProvider = Provider<LinkLauncher>(
  (ref) => const UrlLauncherLink(),
);

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => PlatformImagePicker(),
);
