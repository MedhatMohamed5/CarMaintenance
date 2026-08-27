import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Where the car was left, and what the driver wrote down about it.
///
/// **One pin at a time, per vehicle.** A parking spot is not history — the
/// moment you have walked back to the car the old pin is noise, so saving a new
/// one replaces the last rather than appending to a list.
///
/// [latitude] and [longitude] are what maps navigate to; [floorOrSection] and
/// [note] are what actually finds the car once you are in the garage, where GPS
/// stops being useful. Both are optional: a pin with no note is still worth
/// more than nothing.
class SavedParkingLocation extends Equatable {
  const SavedParkingLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.note,
    this.floorOrSection,
    this.vehicleId,
  });

  final String id;
  final double latitude;
  final double longitude;

  /// When the car was parked, not when the record was last touched — it is what
  /// the driver reads to know how long they have been away.
  final DateTime timestamp;

  final String? note;

  /// Floor, zone or bay: `دور -2 قطعة B14`. Free text on purpose, because
  /// every garage numbers itself differently.
  final String? floorOrSection;

  /// Which car this pin belongs to. Null on records written before the app
  /// tracked more than one vehicle; those are treated as belonging to whichever
  /// vehicle is active.
  final String? vehicleId;

  /// Whether the coordinates are usable at all.
  ///
  /// A failed GPS read can hand back `0, 0` — a real point in the Gulf of
  /// Guinea, and never where anyone parked. Treated as "no fix" so the map
  /// button hides itself instead of sending the driver to the Atlantic.
  bool get hasFix =>
      latitude.abs() > 0.0001 &&
      longitude.abs() > 0.0001 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  /// Something written down beyond the coordinates.
  bool get hasDetails =>
      (note != null && note!.trim().isNotEmpty) ||
      (floorOrSection != null && floorOrSection!.trim().isNotEmpty);

  SavedParkingLocation copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? note,
    String? floorOrSection,
    String? vehicleId,
    bool clearNote = false,
    bool clearFloorOrSection = false,
  }) => SavedParkingLocation(
    id: id,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    timestamp: timestamp ?? this.timestamp,
    note: clearNote ? null : (note ?? this.note),
    floorOrSection: clearFloorOrSection
        ? null
        : (floorOrSection ?? this.floorOrSection),
    vehicleId: vehicleId ?? this.vehicleId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
    'floorOrSection': floorOrSection,
    'vehicleId': vehicleId,
  };

  /// Returns null rather than throwing on anything malformed.
  ///
  /// This is read at startup from a store an older build wrote. A pin that
  /// cannot be understood should mean "no pin saved", never a crash on launch.
  static SavedParkingLocation? fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    final stamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    if (lat == null || lng == null || stamp == null) return null;

    return SavedParkingLocation(
      id: json['id'] as String? ?? stamp.microsecondsSinceEpoch.toString(),
      latitude: lat,
      longitude: lng,
      timestamp: stamp,
      note: json['note'] as String?,
      floorOrSection: json['floorOrSection'] as String?,
      vehicleId: json['vehicleId'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static SavedParkingLocation? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? fromJson(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    id,
    latitude,
    longitude,
    timestamp,
    note,
    floorOrSection,
    vehicleId,
  ];
}
