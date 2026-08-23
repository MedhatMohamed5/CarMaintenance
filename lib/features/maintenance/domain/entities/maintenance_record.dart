import 'package:equatable/equatable.dart';

import 'consumable_part.dart';
import 'service_catalog.dart';
import 'service_milestone.dart';

/// A service that actually happened.
class MaintenanceRecord extends Equatable {
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.title,
    required this.tier,
    this.replacedParts = const [],
    this.inspectedKeys = const [],
    this.customItems = const [],
    this.cost = 0,
    this.workshopName,
    this.notes,
    this.milestoneOdometer,
    this.milestonePhase,
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final int odometer;
  final String title;
  final ServiceTier tier;

  /// Parts fitted new during this service. Each one also produces a
  /// [PartReplacement] so the health bars reset.
  final List<ConsumablePart> replacedParts;

  final List<String> inspectedKeys;

  /// Free-text line items the catalogue does not cover.
  final List<String> customItems;

  final double cost;
  final String? workshopName;
  final String? notes;

  /// Suggested odometer this service was logged against, at the time it was
  /// logged. Historical/informational only — the schedule no longer matches
  /// records against this value because it does not move once the schedule
  /// ahead of it drifts. Kept for display and for inferring [milestonePhase]
  /// on records saved before that field existed.
  final int? milestoneOdometer;

  /// The periodic phase this service closes (0 = break-in check, 1, 2, 3 … =
  /// successive 10,000 km intervals). Stable — this, not [milestoneOdometer],
  /// is what the schedule matches on, and what makes re-logging the same
  /// phase an edit rather than a duplicate even after the target it was
  /// originally offered against has moved.
  final int? milestonePhase;

  /// [milestonePhase] when set; otherwise inferred from a pre-phase record's
  /// grid-aligned [milestoneOdometer].
  int? get resolvedMilestonePhase =>
      milestonePhase ?? ServiceCatalog.legacyPhaseFor(milestoneOdometer);

  MaintenanceRecord copyWith({
    DateTime? date,
    int? odometer,
    String? title,
    ServiceTier? tier,
    List<ConsumablePart>? replacedParts,
    List<String>? inspectedKeys,
    List<String>? customItems,
    double? cost,
    String? workshopName,
    String? notes,
    int? milestoneOdometer,
    int? milestonePhase,
  }) => MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    date: date ?? this.date,
    odometer: odometer ?? this.odometer,
    title: title ?? this.title,
    tier: tier ?? this.tier,
    replacedParts: replacedParts ?? this.replacedParts,
    inspectedKeys: inspectedKeys ?? this.inspectedKeys,
    customItems: customItems ?? this.customItems,
    cost: cost ?? this.cost,
    workshopName: workshopName ?? this.workshopName,
    notes: notes ?? this.notes,
    milestoneOdometer: milestoneOdometer ?? this.milestoneOdometer,
    milestonePhase: milestonePhase ?? this.milestonePhase,
  );

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    date,
    odometer,
    title,
    tier,
    replacedParts,
    inspectedKeys,
    customItems,
    cost,
    workshopName,
    notes,
    milestoneOdometer,
    milestonePhase,
  ];
}
