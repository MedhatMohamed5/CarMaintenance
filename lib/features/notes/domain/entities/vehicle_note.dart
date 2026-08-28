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
  });

  final String id;
  final String vehicleId;
  final String text;
  final DateTime createdAt;
  final bool isDone;

  /// Set the moment [isDone] flips true, cleared if it flips back — so a
  /// re-opened item never shows a stale completion date.
  final DateTime? doneAt;

  VehicleNote copyWith({String? text}) => VehicleNote(
    id: id,
    vehicleId: vehicleId,
    text: text ?? this.text,
    createdAt: createdAt,
    isDone: isDone,
    doneAt: doneAt,
  );

  /// Flips [isDone] and stamps or clears [doneAt] to match.
  VehicleNote toggleDone() => VehicleNote(
    id: id,
    vehicleId: vehicleId,
    text: text,
    createdAt: createdAt,
    isDone: !isDone,
    doneAt: isDone ? null : DateTime.now(),
  );

  @override
  List<Object?> get props => [id, vehicleId, text, createdAt, isDone, doneAt];
}
