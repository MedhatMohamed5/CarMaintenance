import '../../../../core/utils/json_x.dart';
import '../../domain/entities/vehicle_note.dart';

class VehicleNoteModel extends VehicleNote {
  const VehicleNoteModel({
    required super.id,
    required super.vehicleId,
    required super.text,
    required super.createdAt,
    super.isDone,
    super.doneAt,
  });

  factory VehicleNoteModel.fromEntity(VehicleNote n) => VehicleNoteModel(
    id: n.id,
    vehicleId: n.vehicleId,
    text: n.text,
    createdAt: n.createdAt,
    isDone: n.isDone,
    doneAt: n.doneAt,
  );

  factory VehicleNoteModel.fromJson(Map<String, dynamic> json) =>
      VehicleNoteModel(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: JsonX.dateOr(json['createdAt'], DateTime.now()),
        isDone: JsonX.boolOr(json['isDone'], false),
        doneAt: JsonX.date(json['doneAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'isDone': isDone,
    'doneAt': doneAt?.toIso8601String(),
  };

  factory VehicleNoteModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => VehicleNoteModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
