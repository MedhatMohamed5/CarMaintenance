import 'package:flutter/widgets.dart';

import 'local_file_image_stub.dart'
    if (dart.library.io) 'local_file_image_io.dart'
    if (dart.library.js_interop) 'local_file_image_web.dart';

/// Resolves a filesystem path to an [ImageProvider]. Returns null on platforms
/// with no filesystem, so callers fall through to their placeholder.
ImageProvider? localFileImage(String path) => createLocalFileImage(path);
