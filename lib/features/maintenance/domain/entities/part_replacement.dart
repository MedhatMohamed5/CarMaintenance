import 'package:equatable/equatable.dart';

import 'consumable_part.dart';

/// A record that a wearing part was fitted new at a given odometer reading.
/// This is what "resets" a health bar back to 100%.
class PartReplacement extends Equatable {
  const PartReplacement({
    required this.id,
    required this.vehicleId,
    required this.part,
    required this.odometer,
    required this.date,
    this.cost,
    this.notes,
    this.maintenanceRecordId,
  });

  final String id;
  final String vehicleId;
  final ConsumablePart part;
  final int odometer;
  final DateTime date;
  final double? cost;
  final String? notes;

  /// Set when the replacement was captured as part of a logged service, so the
  /// two histories stay linked.
  final String? maintenanceRecordId;

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    part,
    odometer,
    date,
    cost,
    notes,
    maintenanceRecordId,
  ];
}
