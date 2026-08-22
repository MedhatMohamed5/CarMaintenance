import 'package:equatable/equatable.dart';

/// Where a part's wear baseline came from. Drives both the calculation
/// priority and what the UI tells the user.
enum PartBaselineSource {
  /// User typed an exact odometer (or km-driven) for this part.
  manual,

  /// Derived from a logged replacement or service.
  logged,

  /// No history: inferred from the nearest milestone below the vehicle's
  /// initial odometer.
  assumed,

  /// User pinned a wear percentage directly.
  customWear,
}

/// Per-vehicle, per-part configuration. Every field is optional — an absent
/// value falls back to the catalogue default or to logged history.
class PartSetting extends Equatable {
  const PartSetting({
    this.intervalKm,
    this.lastReplacedOdometer,
    this.lastReplacedDate,
    this.customWear,
  });

  /// Overrides the catalogue lifespan for this vehicle.
  final int? intervalKm;

  /// Odometer at which this specific part was last replaced.
  final int? lastReplacedOdometer;

  final DateTime? lastReplacedDate;

  /// Manual wear override as a fraction (0.0 = new, 1.0 = fully consumed).
  /// Values above 1.0 are allowed and surface as an over-limit warning.
  final double? customWear;

  bool get isEmpty =>
      intervalKm == null &&
      lastReplacedOdometer == null &&
      lastReplacedDate == null &&
      customWear == null;

  PartSetting copyWith({
    int? intervalKm,
    int? lastReplacedOdometer,
    DateTime? lastReplacedDate,
    double? customWear,
    bool clearInterval = false,
    bool clearBaseline = false,
    bool clearCustomWear = false,
  }) => PartSetting(
    intervalKm: clearInterval ? null : (intervalKm ?? this.intervalKm),
    lastReplacedOdometer: clearBaseline
        ? null
        : (lastReplacedOdometer ?? this.lastReplacedOdometer),
    lastReplacedDate: clearBaseline
        ? null
        : (lastReplacedDate ?? this.lastReplacedDate),
    customWear: clearCustomWear ? null : (customWear ?? this.customWear),
  );

  Map<String, dynamic> toJson() => {
    'intervalKm': intervalKm,
    'lastReplacedOdometer': lastReplacedOdometer,
    'lastReplacedDate': lastReplacedDate?.toIso8601String(),
    'customWear': customWear,
  };

  factory PartSetting.fromJson(Map<String, dynamic> json) => PartSetting(
    intervalKm: (json['intervalKm'] as num?)?.toInt(),
    lastReplacedOdometer: (json['lastReplacedOdometer'] as num?)?.toInt(),
    lastReplacedDate: json['lastReplacedDate'] == null
        ? null
        : DateTime.tryParse('${json['lastReplacedDate']}'),
    customWear: (json['customWear'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [
    intervalKm,
    lastReplacedOdometer,
    lastReplacedDate,
    customWear,
  ];
}
