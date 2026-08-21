import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'platform_capabilities.dart';

enum VehicleImageSource { camera, gallery, files }

abstract interface class ImagePickerService {
  bool get supportsCamera;

  List<VehicleImageSource> get availableSources;

  Future<String?> pickAsBase64(VehicleImageSource source);
}

class PlatformImagePicker implements ImagePickerService {
  PlatformImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxWidth = 1280;
  static const double _maxHeight = 1280;
  static const int _quality = 78;
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
  Future<String?> pickAsBase64(VehicleImageSource source) async {
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

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxBytes) {
        debugPrint(
          'Vehicle image rejected: ${bytes.lengthInBytes} bytes exceeds cap',
        );
        return null;
      }
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Image pick failed: $e');
      return null;
    }
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
