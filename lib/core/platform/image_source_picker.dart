import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../firebase/crash_reporter.dart';
import 'platform_capabilities.dart';

enum VehicleImageSource { camera, gallery, files }

/// What a multi-selection produced.
///
/// **[rejected] is why this is a record and not a plain list.** Files over the
/// size cap used to be dropped and logged, so picking five receipts and getting
/// three back looked identical to picking three — the user had no way to tell
/// the app had refused anything. Counting them lets the caller say so.
typedef PickedImages = ({List<String> encoded, int rejected});

/// What a single pick produced. [rejected] tells a photo the app could not
/// attach apart from a picker the driver closed, which both leave [encoded]
/// null.
typedef PickedImage = ({String? encoded, bool rejected});

abstract interface class ImagePickerService {
  bool get supportsCamera;

  List<VehicleImageSource> get availableSources;

  /// One image, encoded as base64 and brought under [maxBytes].
  Future<PickedImage> pickAsBase64(VehicleImageSource source, {int? maxBytes});

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
  Future<PickedImage> pickAsBase64(
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
      if (file == null) return (encoded: null, rejected: false);
      // Awaited inside the try, so a read failure lands in the catch below
      // rather than escaping as an unhandled asynchronous error.
      final encoded = await _encode(file, maxBytes ?? _maxBytes);
      return (encoded: encoded, rejected: encoded == null);
    } on Object catch (e, stack) {
      // Null here also means "the driver backed out", so a failure that is
      // reported nowhere is a failure that looks exactly like a decision.
      debugPrint('Image pick failed: $e');
      CrashReporter.recordError(
        e,
        stack,
        reason: 'image pick failed',
        tags: {'action': 'pick-image'},
      );
      return (encoded: null, rejected: true);
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
    } on Object catch (e, stack) {
      debugPrint('Multi image pick failed: $e');
      CrashReporter.recordError(
        e,
        stack,
        reason: 'multi image pick failed',
        tags: {'action': 'pick-image'},
      );
      return (encoded: const <String>[], rejected: 0);
    }
  }

  /// Reads and encodes one file, shrinking it first when it is over
  /// [maxBytes]. Null only when it cannot be brought under the cap at all.
  ///
  /// The cap is checked against the *raw* bytes; base64 inflates them by about
  /// a third, and it is the encoded string that has to fit in the record.
  ///
  /// The picker's own resize is not enough on its own: its quality setting
  /// only applies to JPEG, so a screenshot or an edited photo saved as PNG
  /// came through at full weight, and a detailed JPEG could still be over.
  /// Those were refused, and edited copies failed the same way.
  Future<String?> _encode(XFile file, int maxBytes) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes <= maxBytes) return base64Encode(bytes);

    final shrunk = await compute(_shrinkToFit, (
      bytes: bytes,
      maxBytes: maxBytes,
    ));
    if (shrunk == null) {
      debugPrint('Image rejected: ${bytes.lengthInBytes} bytes, cannot fit');
      return null;
    }
    return base64Encode(shrunk);
  }
}

/// Below this on its longer side a photo stops being worth keeping, so the
/// shrinking gives up rather than go further.
const int _minShrinkSide = 480;

/// Re-encodes an image as JPEG, lowering the quality and then the size until
/// it fits under the cap.
///
/// Runs off the UI thread, since decoding and re-encoding a full photo takes
/// long enough to drop frames. Null when the format cannot be decoded here
/// (HEIC, say) or the smallest step is still too big.
Uint8List? _shrinkToFit(({Uint8List bytes, int maxBytes}) input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);

  // JPEG has no transparency; laid on white, a cut-out screenshot keeps its
  // look instead of turning black.
  if (image.numChannels == 4) {
    final flat = img.Image(width: image.width, height: image.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(flat, image);
  }

  while (true) {
    for (final quality in const [80, 70, 60, 50]) {
      final out = img.encodeJpg(image, quality: quality);
      if (out.lengthInBytes <= input.maxBytes) return out;
    }
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= _minShrinkSide) return null;
    image = img.copyResize(image, width: (image.width * 0.75).round());
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
