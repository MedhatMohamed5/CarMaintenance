import 'dart:typed_data';

import '../../../../core/error/expected_exception.dart';
import '../entities/vehicle.dart';
import '../entities/vehicle_transfer_bundle.dart';

/// Raised when a picked file is not a vehicle transfer document this build can
/// read. Carries no infrastructure detail — the UI shows a translated message,
/// never a parser error.
///
/// An [ExpectedException]: every reason below describes the file the driver
/// picked, not a fault in the app, so none of them is sent to crash reporting.
class VehicleTransferException implements ExpectedException {
  const VehicleTransferException(this.reason);

  final VehicleTransferFailure reason;

  @override
  String toString() => 'VehicleTransferException(${reason.name})';
}

enum VehicleTransferFailure {
  /// Not JSON, or not a JSON object.
  malformed,

  /// JSON, but not a vehicle transfer document.
  wrongFormat,

  /// The report this app exports as JSON from "Export report". It is the
  /// likeliest wrong file to pick — same app, same extension — so it gets a
  /// message that says where the right one comes from.
  reportFile,

  /// Written by a newer build than this one.
  unsupportedVersion,
}

/// Turns a [VehicleTransferBundle] into a standalone document and back.
abstract interface class VehicleTransferCodec {
  Uint8List encode(VehicleTransferBundle bundle);

  /// Throws [VehicleTransferException] when [bytes] are not a readable
  /// document.
  VehicleTransferBundle decode(Uint8List bytes);

  String fileNameFor(Vehicle vehicle);

  String get mimeType;

  /// Extensions the file picker should offer, without dots.
  List<String> get extensions;
}
