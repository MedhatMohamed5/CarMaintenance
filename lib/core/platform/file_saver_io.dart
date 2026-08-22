import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_saver.dart';

/// Writes exports where the user can actually find them.
///
/// The app's own sandbox — `getApplicationDocumentsDirectory`, and worse,
/// `Directory.systemTemp` — is invisible to a file manager and gets swept by
/// the OS. Exports are documents the user asked for, so they go to public
/// storage and the resolved path is handed back for the confirmation snack.
///
/// Resolution order, first writable location wins:
///
/// | Platform | Order |
/// |---|---|
/// | Android | `/storage/emulated/0/Download` → external Downloads → external app dir → documents |
/// | iOS | documents (exposed in Files when `UIFileSharingEnabled` is set) |
/// | Desktop | `getDownloadsDirectory()` → documents |
///
/// Every step is guarded: a missing plugin, a denied permission or a read-only
/// volume falls through to the next candidate rather than throwing, so an
/// export never fails outright over a directory choice.
class IoFileSaver implements FileSaver {
  const IoFileSaver();

  /// The conventional public Downloads path on Android. Writable without
  /// `MANAGE_EXTERNAL_STORAGE` on many devices; when it is not, the next
  /// candidate takes over.
  static const String _androidPublicDownloads = '/storage/emulated/0/Download';

  @override
  Future<SavedFile> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final directory = await _resolveDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return SavedFile(fileName: fileName, path: file.path);
  }

  Future<Directory> _resolveDirectory() async {
    for (final candidate in await _candidates()) {
      final directory = await _prepare(candidate);
      if (directory != null) return directory;
    }
    // Unreachable in practice: the documents directory is the last candidate
    // and always exists. Kept explicit so the return type stays non-nullable.
    return getApplicationDocumentsDirectory();
  }

  Future<List<Directory?>> _candidates() async {
    if (Platform.isAndroid) {
      return [
        Directory(_androidPublicDownloads),
        await _first(
          () => getExternalStorageDirectories(type: StorageDirectory.downloads),
        ),
        await _one(getExternalStorageDirectory),
        await _one(getApplicationDocumentsDirectory),
      ];
    }

    if (Platform.isIOS) {
      // The iOS documents directory is the app's Files-visible folder; there is
      // no public Downloads to write to.
      return [await _one(getApplicationDocumentsDirectory)];
    }

    return [
      await _one(getDownloadsDirectory),
      await _one(getApplicationDocumentsDirectory),
    ];
  }

  /// Creates the directory if needed and proves it is writable by round-tripping
  /// a probe file. A path that exists but rejects writes is not a candidate.
  Future<Directory?> _prepare(Directory? directory) async {
    if (directory == null) return null;
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      final probe = File(
        '${directory.path}${Platform.pathSeparator}.vehicle_care_write_test',
      );
      await probe.writeAsBytes(const [0], flush: true);
      await probe.delete();
      return directory;
    } on Object {
      return null;
    }
  }

  Future<Directory?> _one(Future<Directory?> Function() lookup) async {
    try {
      return await lookup();
    } on Object {
      // MissingPluginException, UnsupportedError, platform exceptions: all mean
      // "not this one".
      return null;
    }
  }

  Future<Directory?> _first(Future<List<Directory>?> Function() lookup) async {
    try {
      final directories = await lookup();
      return (directories == null || directories.isEmpty)
          ? null
          : directories.first;
    } on Object {
      return null;
    }
  }
}

FileSaver createPlatformFileSaver() => const IoFileSaver();
