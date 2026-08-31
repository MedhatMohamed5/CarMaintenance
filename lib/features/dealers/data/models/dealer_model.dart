import '../../../../core/utils/json_x.dart';
import '../../domain/entities/dealer.dart';

class DealerModel extends Dealer {
  const DealerModel({
    required super.id,
    required super.name,
    required super.city,
    required super.kind,
    super.brand,
    super.address,
    super.phone,
    super.altPhone,
    super.hotline,
    super.latitude,
    super.longitude,
    super.openingHours,
    super.rating,
    super.ratingCount,
    super.serviceKeys,
    super.isUserAdded,
    super.isUserEdited,
    super.notes,
  });

  factory DealerModel.fromEntity(Dealer d) => DealerModel(
    id: d.id,
    name: d.name,
    city: d.city,
    kind: d.kind,
    brand: d.brand,
    address: d.address,
    phone: d.phone,
    altPhone: d.altPhone,
    hotline: d.hotline,
    latitude: d.latitude,
    longitude: d.longitude,
    openingHours: d.openingHours,
    rating: d.rating,
    ratingCount: d.ratingCount,
    serviceKeys: d.serviceKeys,
    isUserAdded: d.isUserAdded,
    isUserEdited: d.isUserEdited,
    notes: d.notes,
  );

  factory DealerModel.fromJson(Map<String, dynamic> json) => DealerModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    kind: DealerKind.fromName(json['kind'] as String?),
    brand: json['brand'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    altPhone: json['altPhone'] as String?,
    hotline: json['hotline'] as String?,
    latitude: JsonX.doubleOrNull(json['latitude']),
    longitude: JsonX.doubleOrNull(json['longitude']),
    openingHours: json['openingHours'] as String?,
    rating: JsonX.doubleOrNull(json['rating']),
    ratingCount: JsonX.intOr(json['ratingCount'], 0),
    serviceKeys: JsonX.stringList(json['serviceKeys']),
    isUserAdded: JsonX.boolOr(json['isUserAdded'], false),
    isUserEdited: JsonX.boolOr(json['isUserEdited'], false),
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'kind': kind.name,
    'brand': brand,
    'address': address,
    'phone': phone,
    'altPhone': altPhone,
    'hotline': hotline,
    'latitude': latitude,
    'longitude': longitude,
    'openingHours': openingHours,
    'rating': rating,
    'ratingCount': ratingCount,
    'serviceKeys': serviceKeys,
    'isUserAdded': isUserAdded,
    'isUserEdited': isUserEdited,
    'notes': notes,
  };

  factory DealerModel.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) => DealerModel.fromJson({...data, 'id': documentId});

  Map<String, dynamic> toFirestore() => {
    ...toJson()..remove('id'),
    'updatedAt': DateTime.now().toIso8601String(),
  };
}
