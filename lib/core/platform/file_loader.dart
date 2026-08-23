import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A file the user chose from their device, already read into memory.
///
/// Bytes rather than a path, deliberately: on web a picked file has no
/// filesystem path to read back from, and every caller here parses one small
/// document in full anyway.
class LoadedFile {
  const LoadedFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// Reading counterpart of `FileSaver`, kept behind the same kind of interface
/// so the picker package stays confined to this file.
abstract interface class FileLoader {
  /// Prompts for a single file, filtered to [extensions] (without dots).
  ///
  /// Returns null when the user dismisses the picker — a cancellation is a
  /// normal outcome, not a failure.
  Future<LoadedFile?> pick({required List<String> extensions});
}

class PlatformFileLoader implements FileLoader {
  const PlatformFileLoader();

  @override
  Future<LoadedFile?> pick({required List<String> extensions}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    return LoadedFile(fileName: file.name, bytes: await file.readAsBytes());
  }
}

FileLoader createFileLoader() => const PlatformFileLoader();
