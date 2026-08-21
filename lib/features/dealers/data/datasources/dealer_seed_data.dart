import '../../domain/entities/dealer.dart';

class DealerSeedData {
  const DealerSeedData._();

  static const int seedVersion = 2;

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

  static Set<String> get seedIds => all().map((d) => d.id).toSet();
}
