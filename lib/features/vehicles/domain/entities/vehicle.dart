import 'package:equatable/equatable.dart';

/// A vehicle the user tracks. Brand-agnostic by design — [make] is free text
/// so the app works for any car, van or motorcycle.
class Vehicle extends Equatable {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.initialOdometer,
    required this.currentOdometer,
    required this.createdAt,
    this.nickname,
    this.plateNumber,
    this.purchaseDate,
    this.licenseExpiry,
    this.insuranceExpiry,
    this.tankCapacityLiters,
    this.colorValue,
    this.partLifespanOverridesKm = const {},
    this.odometerUpdatedAt,
  });

  final String id;
  final String make;
  final String model;
  final int year;

  /// Reading at the moment the vehicle was added — the baseline every
  /// "distance driven with us" figure is measured from.
  final int initialOdometer;
  final int currentOdometer;

  final DateTime createdAt;
  final String? nickname;
  final String? plateNumber;
  final DateTime? purchaseDate;
  final DateTime? licenseExpiry;
  final DateTime? insuranceExpiry;
  final double? tankCapacityLiters;

  /// ARGB value used to tint this vehicle across the UI, so switching cars is
  /// recognisable at a glance.
  final int? colorValue;

  /// Per-vehicle overrides of the default part lifespans, keyed by
  /// `ConsumablePart.id`. A 4x4 on rough roads can shorten tyre life here.
  final Map<String, int> partLifespanOverridesKm;

  final DateTime? odometerUpdatedAt;

  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty)
      ? nickname!.trim()
      : '$make $model';

  String get subtitle => '$make $model · $year';

  /// Distance covered since the vehicle joined the app.
  int get trackedDistanceKm =>
      (currentOdometer - initialOdometer).clamp(0, 1 << 31);

  Vehicle copyWith({
    String? make,
    String? model,
    int? year,
    int? initialOdometer,
    int? currentOdometer,
    String? nickname,
    String? plateNumber,
    DateTime? purchaseDate,
    DateTime? licenseExpiry,
    DateTime? insuranceExpiry,
    double? tankCapacityLiters,
    int? colorValue,
    Map<String, int>? partLifespanOverridesKm,
    DateTime? odometerUpdatedAt,
    bool clearLicenseExpiry = false,
    bool clearInsuranceExpiry = false,
  }) => Vehicle(
    id: id,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    initialOdometer: initialOdometer ?? this.initialOdometer,
    currentOdometer: currentOdometer ?? this.currentOdometer,
    createdAt: createdAt,
    nickname: nickname ?? this.nickname,
    plateNumber: plateNumber ?? this.plateNumber,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    licenseExpiry: clearLicenseExpiry
        ? null
        : (licenseExpiry ?? this.licenseExpiry),
    insuranceExpiry: clearInsuranceExpiry
        ? null
        : (insuranceExpiry ?? this.insuranceExpiry),
    tankCapacityLiters: tankCapacityLiters ?? this.tankCapacityLiters,
    colorValue: colorValue ?? this.colorValue,
    partLifespanOverridesKm:
        partLifespanOverridesKm ?? this.partLifespanOverridesKm,
    odometerUpdatedAt: odometerUpdatedAt ?? this.odometerUpdatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    make,
    model,
    year,
    initialOdometer,
    currentOdometer,
    createdAt,
    nickname,
    plateNumber,
    purchaseDate,
    licenseExpiry,
    insuranceExpiry,
    tankCapacityLiters,
    colorValue,
    partLifespanOverridesKm,
    odometerUpdatedAt,
  ];
}
