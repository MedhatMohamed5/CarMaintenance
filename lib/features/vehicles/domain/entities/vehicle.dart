import 'package:equatable/equatable.dart';

import '../../../maintenance/domain/entities/part_setting.dart';

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
    this.imageBase64,
    this.imageUrl,
    this.partLifespanOverridesKm = const {},
    this.partSettings = const {},
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

  /// Base64-encoded, downscaled photo. Stored inline so it round-trips
  /// through Hive and Firestore identically on mobile and web.
  final String? imageBase64;

  /// Network URL or local filesystem path. Complements [imageBase64] so a
  /// vehicle synced from Firestore can reference remote artwork.
  final String? imageUrl;

  /// Per-vehicle overrides of the default part lifespans, keyed by
  /// `ConsumablePart.id`. A 4x4 on rough roads can shorten tyre life here.
  final Map<String, int> partLifespanOverridesKm;

  /// Per-part configuration keyed by `ConsumablePart.id`: interval override,
  /// explicit last-replaced odometer, or a pinned wear percentage.
  final Map<String, PartSetting> partSettings;

  /// Settings for one part, merging the legacy interval-only map so vehicles
  /// saved before per-part settings existed keep their overrides.
  PartSetting settingFor(String partId) {
    final setting = partSettings[partId] ?? const PartSetting();
    final legacyInterval = partLifespanOverridesKm[partId];
    if (setting.intervalKm != null || legacyInterval == null) return setting;
    return setting.copyWith(intervalKm: legacyInterval);
  }

  final DateTime? odometerUpdatedAt;

  bool get hasImage =>
      (imageBase64 != null && imageBase64!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  String get displayName => (nickname != null && nickname!.trim().isNotEmpty)
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
    String? imageBase64,
    String? imageUrl,
    Map<String, int>? partLifespanOverridesKm,
    Map<String, PartSetting>? partSettings,
    DateTime? odometerUpdatedAt,
    bool clearLicenseExpiry = false,
    bool clearInsuranceExpiry = false,
    bool clearImage = false,
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
    imageBase64: clearImage ? null : (imageBase64 ?? this.imageBase64),
    imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    partLifespanOverridesKm:
        partLifespanOverridesKm ?? this.partLifespanOverridesKm,
    partSettings: partSettings ?? this.partSettings,
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
    imageBase64,
    imageUrl,
    partLifespanOverridesKm,
    partSettings,
    odometerUpdatedAt,
  ];
}
