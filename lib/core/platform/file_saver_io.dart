import 'dart:io';
import 'dart:typed_data';

import 'file_saver.dart';

class IoFileSaver implements FileSaver {
  const IoFileSaver();

  @override
  Future<SavedFile> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}vehicle_care',
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);

    return SavedFile(fileName: fileName, path: file.path);
  }
}

FileSaver createPlatformFileSaver() => const IoFileSaver();
