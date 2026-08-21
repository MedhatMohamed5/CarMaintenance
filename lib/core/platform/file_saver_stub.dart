import 'file_saver.dart';

FileSaver createPlatformFileSaver() =>
    throw UnsupportedError('No FileSaver implementation for this platform');
