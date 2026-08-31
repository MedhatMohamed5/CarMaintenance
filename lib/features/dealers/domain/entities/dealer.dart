import 'package:equatable/equatable.dart';

enum DealerKind {
  authorizedService(l10nKey: 'kindAuthorizedService'),
  specializedCenter(l10nKey: 'kindSpecializedCenter'),
  showroom(l10nKey: 'kindShowroom'),
  independentWorkshop(l10nKey: 'kindWorkshop'),
  tireShop(l10nKey: 'kindTireShop'),
  towing(l10nKey: 'kindTowing');

  const DealerKind({required this.l10nKey});

  final String l10nKey;

  static DealerKind fromName(String? name) => DealerKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => DealerKind.independentWorkshop,
  );
}

/// A service centre, showroom or workshop the user can call or navigate to.
class Dealer extends Equatable {
  const Dealer({
    required this.id,
    required this.name,
    required this.city,
    required this.kind,
    this.brand,
    this.address,
    this.phone,
    this.altPhone,
    this.hotline,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.rating,
    this.ratingCount = 0,
    this.serviceKeys = const [],
    this.isUserAdded = false,
    this.isUserEdited = false,
    this.notes,
  });

  final String id;
  final String name;
  final String city;
  final DealerKind kind;

  /// Vehicle brand the centre is authorised for, when applicable.
  final String? brand;

  final String? address;
  final String? phone;
  final String? altPhone;
  final String? hotline;

  /// Optional: when absent, "Open in Maps" falls back to a name + address
  /// search, which stays correct even if a branch relocates.
  final double? latitude;
  final double? longitude;

  final String? openingHours;
  final double? rating;
  final int ratingCount;

  /// Localisation keys of offered services (periodic service, body work …).
  final List<String> serviceKeys;

  final bool isUserAdded;

  /// A published row the driver has corrected — a moved branch, a dead phone
  /// number, a pin they dropped themselves.
  ///
  /// **Distinct from [isUserAdded], and the distinction is what makes an edit
  /// survive.** The directory is republished centrally, and every refresh
  /// overwrites the rows it owns; without this flag a correction lived exactly
  /// until the next publish and then silently reverted, which is worse than not
  /// offering the edit at all. A row carrying it is skipped by the refresh and
  /// syncs to the driver's account like one they added themselves.
  final bool isUserEdited;

  final String? notes;

  /// True for anything the refresh must not touch and the account must keep.
  bool get isUserOwned => isUserAdded || isUserEdited;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get mapQuery => [name, address, city].whereType<String>().join(', ');

  String? get callableNumber => phone ?? hotline ?? altPhone;

  List<String> get allNumbers =>
      [phone, altPhone, hotline].whereType<String>().toList(growable: false);

  Dealer copyWith({
    String? name,
    String? city,
    DealerKind? kind,
    String? brand,
    String? address,
    String? phone,
    String? altPhone,
    String? hotline,
    double? latitude,
    double? longitude,
    String? openingHours,
    double? rating,
    int? ratingCount,
    List<String>? serviceKeys,
    bool? isUserAdded,
    bool? isUserEdited,
    String? notes,
  }) => Dealer(
    id: id,
    name: name ?? this.name,
    city: city ?? this.city,
    kind: kind ?? this.kind,
    brand: brand ?? this.brand,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    hotline: hotline ?? this.hotline,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    openingHours: openingHours ?? this.openingHours,
    rating: rating ?? this.rating,
    ratingCount: ratingCount ?? this.ratingCount,
    serviceKeys: serviceKeys ?? this.serviceKeys,
    isUserAdded: isUserAdded ?? this.isUserAdded,
    isUserEdited: isUserEdited ?? this.isUserEdited,
    notes: notes ?? this.notes,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    city,
    kind,
    brand,
    address,
    phone,
    altPhone,
    hotline,
    latitude,
    longitude,
    openingHours,
    rating,
    ratingCount,
    serviceKeys,
    isUserAdded,
    isUserEdited,
    notes,
  ];
}
