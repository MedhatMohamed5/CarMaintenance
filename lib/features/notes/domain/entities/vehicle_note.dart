import 'package:equatable/equatable.dart';

/// A short, freeform reminder tied to one vehicle — a noise to get checked,
/// a part to buy, anything worth not forgetting. Deliberately has no category
/// or due date: the whole point is that jotting one down costs nothing.
class VehicleNote extends Equatable {
  const VehicleNote({
    required this.id,
    required this.vehicleId,
    required this.text,
    required this.createdAt,
    this.isDone = false,
    this.doneAt,
    this.images = const [],
  });

  final String id;
  final String vehicleId;
  final String text;
  final DateTime createdAt;
  final bool isDone;

  /// Set the moment [isDone] flips true, cleared if it flips back — so a
  /// re-opened item never shows a stale completion date.
  final DateTime? doneAt;

  /// Photos attached to the note, base64-encoded.
  final List<String> images;

  VehicleNote copyWith({String? text, List<String>? images}) => VehicleNote(
    id: id,
    vehicleId: vehicleId,
    text: text ?? this.text,
    createdAt: createdAt,
    isDone: isDone,
    doneAt: doneAt,
    images: images ?? this.images,
  );

  /// Flips [isDone] and stamps or clears [doneAt] to match.
  VehicleNote toggleDone() => VehicleNote(
    id: id,
    vehicleId: vehicleId,
    text: text,
    createdAt: createdAt,
    isDone: !isDone,
    doneAt: isDone ? null : DateTime.now(),
    images: images,
  );

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    text,
    createdAt,
    isDone,
    doneAt,
    images,
  ];
}
