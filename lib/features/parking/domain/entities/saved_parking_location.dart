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
    this.remindAt,
    this.remindAfter,
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

  /// When the driver asked to be reminded to move the car — a meter running
  /// out, a two-hour limit. Null when they did not ask.
  ///
  /// Stored on the pin rather than armed straight away, because the scheduler
  /// cancels and re-arms everything on each pass: a reminder it does not know
  /// about would be cancelled by the next one. Held here, it is re-armed every
  /// time like any other, and goes when the pin goes.
  final DateTime? remindAt;

  /// The period the driver picked for [remindAt] — "after two hours".
  ///
  /// Kept beside the instant because the instant alone cannot say which choice
  /// made it once the reminder has been changed after parking: reopening the
  /// sheet showed the due time but no choice marked. Null when no reminder is
  /// set.
  final Duration? remindAfter;

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
    DateTime? remindAt,
    Duration? remindAfter,
    bool clearNote = false,
    bool clearFloorOrSection = false,
    bool clearRemindAt = false,
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
    remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
    // Cleared with the instant: the two describe one reminder.
    remindAfter: clearRemindAt ? null : (remindAfter ?? this.remindAfter),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
    'floorOrSection': floorOrSection,
    'vehicleId': vehicleId,
    'remindAt': remindAt?.toIso8601String(),
    'remindAfterMinutes': remindAfter?.inMinutes,
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

    final remindAt = DateTime.tryParse(json['remindAt'] as String? ?? '');
    final minutes = (json['remindAfterMinutes'] as num?)?.toInt();

    return SavedParkingLocation(
      id: json['id'] as String? ?? stamp.microsecondsSinceEpoch.toString(),
      latitude: lat,
      longitude: lng,
      timestamp: stamp,
      note: json['note'] as String?,
      floorOrSection: json['floorOrSection'] as String?,
      vehicleId: json['vehicleId'] as String?,
      remindAt: remindAt,
      remindAfter: remindAt == null
          ? null
          : minutes != null
          ? Duration(minutes: minutes)
          : _inferRemindAfter(stamp, remindAt),
    );
  }

  /// The period for a pin written before [remindAfter] was stored.
  ///
  /// A reminder chosen while pinning is due exactly that long after
  /// [timestamp], to the microsecond, so a whole number of hours there is the
  /// choice itself. Anything else was changed after parking and cannot be
  /// recovered; it stays null and no choice is marked, as before.
  static Duration? _inferRemindAfter(DateTime parkedAt, DateTime remindAt) {
    final gap = remindAt.difference(parkedAt);
    if (gap <= Duration.zero ||
        gap.inMicroseconds % Duration.microsecondsPerHour != 0) {
      return null;
    }
    return gap;
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
    remindAt,
    remindAfter,
  ];
}
