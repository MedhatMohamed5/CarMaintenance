import '../../../notes/domain/entities/vehicle_note.dart';
import 'vehicle_transfer_bundle.dart';

/// Everything a vehicle deletion took with it, held just long enough to put it
/// back.
///
/// **Deleting a vehicle is the one cascading delete in the app**: it clears
/// that car's fuel history, service records, part replacements, expenses and
/// notes as well. An "undo" that restored the profile alone would be worse
/// than no undo at all — the driver would see the car return and assume they
/// were whole, and only notice years of fill history missing much later.
///
/// The child records ride in a [VehicleTransferBundle] rather than in fields of
/// their own so restoring goes through the same writer an import uses, which is
/// the code that already knows how derived part replacements have to be
/// reconciled against the service records that rebuild them. Notes sit outside
/// the bundle because the transfer file format does not carry them, and
/// widening that format to serve an in-memory snapshot would change what an
/// exported file means.
class DeletedVehicle {
  const DeletedVehicle({
    required this.bundle,
    required this.notes,
    required this.wasSelected,
  });

  final VehicleTransferBundle bundle;
  final List<VehicleNote> notes;

  /// Whether this was the car on screen when it was deleted, so restoring puts
  /// the driver back where they were rather than on whichever vehicle the
  /// garage happened to fall back to.
  final bool wasSelected;

  String get vehicleId => bundle.vehicle.id;
}
