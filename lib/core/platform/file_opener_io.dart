import 'package:open_filex/open_filex.dart';

import 'file_opener.dart';

class IoFileOpener implements FileOpener {
  const IoFileOpener();

  @override
  Future<bool> open(String path, {String? mimeType}) async {
    try {
      final result = await OpenFilex.open(path, type: mimeType);
      return result.type == ResultType.done;
    } on Object {
      // No handler installed, a path the OS will not share, a plugin missing
      // on desktop: the file is written either way, so a failure to open it is
      // reported as "not opened" rather than allowed to surface as a crash on
      // top of a successful export.
      return false;
    }
  }
}

FileOpener createPlatformFileOpener() => const IoFileOpener();
