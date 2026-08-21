import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';

class SavedFile {
  const SavedFile({required this.fileName, this.path, this.downloaded = false});

  final String fileName;
  final String? path;
  final bool downloaded;
}

abstract interface class FileSaver {
  Future<SavedFile> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

FileSaver createFileSaver() => createPlatformFileSaver();
