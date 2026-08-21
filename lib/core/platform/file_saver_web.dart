import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_saver.dart';

class WebFileSaver implements FileSaver {
  const WebFileSaver();

  @override
  Future<SavedFile> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);

    return SavedFile(fileName: fileName, downloaded: true);
  }
}

FileSaver createPlatformFileSaver() => const WebFileSaver();
