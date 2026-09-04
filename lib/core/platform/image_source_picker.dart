import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'platform_capabilities.dart';

enum VehicleImageSource { camera, gallery, files }

/// What a multi-selection produced.
///
/// **[rejected] is why this is a record and not a plain list.** Files over the
/// size cap used to be dropped and logged, so picking five receipts and getting
/// three back looked identical to picking three — the user had no way to tell
/// the app had refused anything. Counting them lets the caller say so.
typedef PickedImages = ({List<String> encoded, int rejected});

abstract interface class ImagePickerService {
  bool get supportsCamera;

  List<VehicleImageSource> get availableSources;

  /// One image, encoded as base64, or null if the picker was dismissed or the
  /// file exceeded [maxBytes].
  Future<String?> pickAsBase64(VehicleImageSource source, {int? maxBytes});

  /// Several images in one pass, for a record that can hold more than one.
  ///
  /// Gallery and file-picker only: a camera takes one photograph at a time, so
  /// repeated single captures are the only shape that exists there.
  Future<PickedImages> pickMultipleAsBase64({int? maxBytes});
}

class PlatformImagePicker implements ImagePickerService {
  PlatformImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxWidth = 1280;
  static const double _maxHeight = 1280;
  static const int _quality = 78;

  /// Ceiling for a single image where the record holds exactly one of them —
  /// the vehicle photo. A record that can hold several passes its own, smaller
  /// budget; see `InvoiceAttachmentField`.
  static const int _maxBytes = 900 * 1024;

  @override
  bool get supportsCamera => AppPlatform.isMobile;

  @override
  List<VehicleImageSource> get availableSources => [
    if (supportsCamera) VehicleImageSource.camera,
    if (AppPlatform.isWeb)
      VehicleImageSource.files
    else
      VehicleImageSource.gallery,
  ];

  @override
  Future<String?> pickAsBase64(
    VehicleImageSource source, {
    int? maxBytes,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: source == VehicleImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      // Awaited inside the try, so a read failure lands in the catch below
      // rather than escaping as an unhandled asynchronous error.
      return await _encode(file, maxBytes ?? _maxBytes);
    } catch (e) {
      debugPrint('Image pick failed: $e');
      return null;
    }
  }

  @override
  Future<PickedImages> pickMultipleAsBase64({int? maxBytes}) async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        imageQuality: _quality,
        requestFullMetadata: false,
      );

      final cap = maxBytes ?? _maxBytes;
      final encoded = <String>[];
      var rejected = 0;
      for (final file in files) {
        final result = await _encode(file, cap);
        if (result == null) {
          rejected++;
        } else {
          encoded.add(result);
        }
      }
      return (encoded: encoded, rejected: rejected);
    } catch (e) {
      debugPrint('Multi image pick failed: $e');
      return (encoded: const <String>[], rejected: 0);
    }
  }

  /// Reads and encodes one file, or returns null when it is over [maxBytes].
  ///
  /// The cap is checked against the *raw* bytes; base64 inflates them by about
  /// a third, and it is the encoded string that has to fit in the record.
  Future<String?> _encode(XFile file, int maxBytes) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxBytes) {
      debugPrint(
        'Image rejected: ${bytes.lengthInBytes} bytes exceeds $maxBytes',
      );
      return null;
    }
    return base64Encode(bytes);
  }
}

class VehicleImage {
  const VehicleImage._();

  static Uint8List? decode(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }
}
