import '../../domain/entities/dealer.dart';

/// The directory compiled into the app.
///
/// **A fallback, not a seed.** It was named `DealerSeedData` when it was
/// written into local storage on first launch and the app served the directory
/// from there. Nothing is seeded any more: the standard list comes from Remote
/// Config, this is what shows when nothing is published or when Firebase is not
/// available at all, and it is never persisted. The old name described a
/// mechanism that no longer exists.
class DealerSeedData {
  const DealerSeedData._();

  static const String ezzElarabHotline = '19399';

  static const List<String> _authorizedServices = [
    'srvPeriodic',
    'srvMechanical',
    'srvElectrical',
    'srvBodyPaint',
    'srvSpareParts',
  ];

  static const List<String> _specializedServices = [
    'srvPeriodic',
    'srvMechanical',
    'srvElectrical',
  ];

  static List<Dealer> all() => const [
    Dealer(
      id: 'seed_ezz_abu_rawash',
      name: 'عز العرب - فرع أبو رواش',
      city: 'الجيزة',
      kind: DealerKind.authorizedService,
      brand: 'Ezz Elarab',
      address: 'المنطقة الصناعية، أبو رواش، الجيزة',
      hotline: ezzElarabHotline,
      serviceKeys: _authorizedServices,
    ),
    Dealer(
      id: 'seed_ezz_agouza',
      name: 'عز العرب - فرع العجوزة',
      city: 'الجيزة',
      kind: DealerKind.authorizedService,
      brand: 'Ezz Elarab',
      address: 'العجوزة، الجيزة',
      hotline: ezzElarabHotline,
      serviceKeys: _authorizedServices,
    ),
    Dealer(
      id: 'seed_center_al_aseel',
      name: 'مركز الأصيل لخدمة السيارات',
      city: 'القاهرة',
      kind: DealerKind.specializedCenter,
      address: 'زهراء المعادي، القاهرة',
      phone: '01040006041',
      altPhone: '17282',
      serviceKeys: _specializedServices,
    ),
    Dealer(
      id: 'seed_center_amir_joseph',
      name: 'مركز أمير وجوزيف لخدمة السيارات',
      city: 'القاهرة',
      kind: DealerKind.specializedCenter,
      address: 'حسن المأمون / مكرم عبيد، مدينة نصر، القاهرة',
      phone: '0222721412',
      altPhone: '01223104323',
      serviceKeys: _specializedServices,
    ),
  ];
}
