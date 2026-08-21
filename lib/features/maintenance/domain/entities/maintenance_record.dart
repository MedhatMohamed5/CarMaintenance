import 'package:equatable/equatable.dart';

import 'consumable_part.dart';
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

  /// Set when this service closed a scheduled milestone (e.g. the 40,000 km
  /// service), which is how the roadmap knows a stop is done.
  final int? milestoneOdometer;

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
  ];
}
