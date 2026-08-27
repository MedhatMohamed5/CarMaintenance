import 'file_opener_stub.dart'
    if (dart.library.io) 'file_opener_io.dart'
    if (dart.library.js_interop) 'file_opener_web.dart';

/// Hands a freshly saved export to whatever app the device uses to read it.
///
/// **Not `url_launcher`.** A `file://` URI throws `FileUriExposedException` on
/// Android 7 and up: since Nougat an app may not pass a raw path across a
/// process boundary, and a viewer has to be handed a `content://` URI from a
/// `FileProvider` instead. Wiring that by hand means a provider entry in the
/// manifest and a paths XML for every directory the saver might land in —
/// which is exactly what `open_filex` already carries.
///
/// Web has nothing to do: the browser has already put the file in the
/// download tray, and opening it a second time is the browser's business.
abstract interface class FileOpener {
  /// Opens [path], returning whether anything was able to.
  ///
  /// `false` is a normal outcome, not an error: a device with no PDF viewer
  /// installed is a real situation, and the export itself already succeeded.
  /// The caller says so quietly rather than treating it as a failed save.
  Future<bool> open(String path, {String? mimeType});
}

FileOpener createFileOpener() => createPlatformFileOpener();
