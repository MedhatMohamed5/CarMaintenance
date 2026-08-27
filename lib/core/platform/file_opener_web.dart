import 'file_opener.dart';

/// The browser has already handled it.
///
/// [WebFileSaver] triggers a download, which lands in the download tray and is
/// opened from there. Opening it again from script would either be blocked as
/// a popup or hand the user a second copy.
class WebFileOpener implements FileOpener {
  const WebFileOpener();

  @override
  Future<bool> open(String path, {String? mimeType}) async => false;
}

FileOpener createPlatformFileOpener() => const WebFileOpener();
