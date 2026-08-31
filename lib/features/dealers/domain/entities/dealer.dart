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

  /// Whether the driver added this row themselves.
  ///
  /// **The one thing that decides what may be done to a workshop.** The
  /// standard directory is admin-defined and read-only: it is published to
  /// every user identically, so editing or deleting a row here would either
  /// have to be undone on the next publish or diverge silently from what
  /// everyone else sees. Rows the driver added are theirs — they live in their
  /// account, and only they can change or remove them.
  final bool isUserAdded;

  final String? notes;

  bool get hasCoordinates => latitude != null && longitude != null;

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
    notes,
  ];
}
