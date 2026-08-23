/// A catalogue entry shown in both English and Arabic.
///
/// [en] is the stored value — the form still saves a Latin make/model so
/// existing vehicles and exports stay stable. [ar] is the spoken
/// transliteration used in the picker and in search.
class CatalogName {
  const CatalogName(this.en, this.ar);

  final String en;
  final String ar;

  /// Both scripts on one line, locale-preferred name first.
  String dualLabel({required bool arabic}) => arabic ? '$ar  $en' : '$en  $ar';

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return en.toLowerCase().contains(q) || ar.contains(query);
  }

  @override
  bool operator ==(Object other) => other is CatalogName && other.en == en;

  @override
  int get hashCode => en.hashCode;
}

/// Popular makes and the models that belong to each one.
///
/// Held as compile-time lists so the first open of the add-vehicle sheet
/// does not allocate hundreds of strings on the UI thread. The picker reads
/// this through a Riverpod provider and never copies it into `build`.
class VehicleCatalog {
  const VehicleCatalog();

  /// Sentinel stored in the form when the user wants a free-text value.
  /// Never written to a [Vehicle] — the custom field is what gets saved.
  static const String otherKey = '__other__';

  List<CatalogName> get makes => _makes;

  List<CatalogName> modelsFor(String makeEn) =>
      _modelsByMake[makeEn] ?? const <CatalogName>[];

  bool hasMake(String make) => _modelsByMake.containsKey(make);

  bool hasModel(String make, String model) {
    final models = _modelsByMake[make];
    if (models == null) return false;
    for (final item in models) {
      if (item.en == model) return true;
    }
    return false;
  }

  CatalogName? makeNamed(String en) {
    for (final make in _makes) {
      if (make.en == en) return make;
    }
    return null;
  }

  CatalogName? modelNamed(String make, String en) {
    for (final model in modelsFor(make)) {
      if (model.en == en) return model;
    }
    return null;
  }
}

const _makes = <CatalogName>[
  CatalogName('Toyota', 'تويوتا'),
  CatalogName('Hyundai', 'هيونداي'),
  CatalogName('Kia', 'كيا'),
  CatalogName('Nissan', 'نيسان'),
  CatalogName('Honda', 'هوندا'),
  CatalogName('Chevrolet', 'شيفروليه'),
  CatalogName('Mitsubishi', 'ميتسوبيشي'),
  CatalogName('Suzuki', 'سوزوكي'),
  CatalogName('Renault', 'رينو'),
  CatalogName('Peugeot', 'بيجو'),
  CatalogName('Citroen', 'سيتروين'),
  CatalogName('Volkswagen', 'فولكسفاغن'),
  CatalogName('Skoda', 'سكودا'),
  CatalogName('BMW', 'بي إم دبليو'),
  CatalogName('Mercedes-Benz', 'مرسيدس-بنز'),
  CatalogName('Audi', 'أودي'),
  CatalogName('Mazda', 'مازدا'),
  CatalogName('Ford', 'فورد'),
  CatalogName('Jeep', 'جيب'),
  CatalogName('MG', 'إم جي'),
  CatalogName('Chery', 'شيري'),
  CatalogName('BYD', 'بي واي دي'),
  CatalogName('Geely', 'جيلي'),
  CatalogName('Changan', 'شانجان'),
  CatalogName('Haval', 'هافال'),
  CatalogName('Fiat', 'فيات'),
  CatalogName('Opel', 'أوبل'),
  CatalogName('Seat', 'سيات'),
  CatalogName('Lexus', 'لكزس'),
  CatalogName('Infiniti', 'إنفينيتي'),
  CatalogName('Volvo', 'فولفو'),
  CatalogName('Land Rover', 'لاند روفر'),
  CatalogName('Mini', 'ميني'),
  CatalogName('Tesla', 'تسلا'),
  CatalogName('Isuzu', 'إيسوزو'),
  CatalogName('Daihatsu', 'دايهاتسو'),
  CatalogName('Proton', 'بروتون'),
  CatalogName('Subaru', 'سوبارو'),
  CatalogName('GAC', 'جي إيه سي'),
  CatalogName('Jetour', 'جيتور'),
  CatalogName('Porsche', 'بورشه'),
  CatalogName('Jaguar', 'جاكوار'),
];

const _modelsByMake = <String, List<CatalogName>>{
  'Toyota': [
    CatalogName('Corolla', 'كورولا'),
    CatalogName('Yaris', 'ياريس'),
    CatalogName('Camry', 'كامري'),
    CatalogName('RAV4', 'راف فور'),
    CatalogName('C-HR', 'سي إتش آر'),
    CatalogName('Land Cruiser', 'لاند كروزر'),
    CatalogName('Prado', 'برادو'),
    CatalogName('Fortuner', 'فورتشنر'),
    CatalogName('Hilux', 'هايلكس'),
    CatalogName('Avanza', 'أفانزا'),
    CatalogName('Rush', 'راش'),
    CatalogName('Hiace', 'هايس'),
    CatalogName('Supra', 'سوبرا'),
  ],
  'Hyundai': [
    CatalogName('Elantra', 'إلنترا'),
    CatalogName('Accent', 'أكسنت'),
    CatalogName('Tucson', 'توسان'),
    CatalogName('Santa Fe', 'سانتا في'),
    CatalogName('Creta', 'كريتا'),
    CatalogName('Sonata', 'سوناتا'),
    CatalogName('i10', 'آي تن'),
    CatalogName('i20', 'آي توينتي'),
    CatalogName('Venue', 'فينيو'),
    CatalogName('Palisade', 'باليسايد'),
    CatalogName('Bayon', 'بايون'),
    CatalogName('Ioniq', 'أيونيك'),
  ],
  'Kia': [
    CatalogName('Cerato', 'سيراتو'),
    CatalogName('Sportage', 'سبورتاج'),
    CatalogName('Rio', 'ريو'),
    CatalogName('Picanto', 'بيكانتو'),
    CatalogName('Sorento', 'سورينتو'),
    CatalogName('Seltos', 'سيلتوس'),
    CatalogName('Carnival', 'كرنفال'),
    CatalogName('Pegas', 'بيغاس'),
    CatalogName('K5', 'كي فايف'),
    CatalogName('Soul', 'سول'),
    CatalogName('Telluride', 'تيلورايد'),
  ],
  'Nissan': [
    CatalogName('Sunny', 'صني'),
    CatalogName('Sentra', 'سنترا'),
    CatalogName('Qashqai', 'قشقاي'),
    CatalogName('X-Trail', 'إكس تريل'),
    CatalogName('Patrol', 'باترول'),
    CatalogName('Juke', 'جوك'),
    CatalogName('Altima', 'التيما'),
    CatalogName('Navara', 'نافارا'),
    CatalogName('Kicks', 'كيكس'),
    CatalogName('Tiida', 'تيدا'),
  ],
  'Honda': [
    CatalogName('Civic', 'سيفيك'),
    CatalogName('Accord', 'أكورد'),
    CatalogName('CR-V', 'سي آر في'),
    CatalogName('HR-V', 'إتش آر في'),
    CatalogName('City', 'سيتي'),
    CatalogName('Jazz', 'جاز'),
    CatalogName('Pilot', 'بايلوت'),
  ],
  'Chevrolet': [
    CatalogName('Aveo', 'أفيو'),
    CatalogName('Cruze', 'كروز'),
    CatalogName('Optra', 'أوبترا'),
    CatalogName('Captiva', 'كابتيفا'),
    CatalogName('Spark', 'سبارك'),
    CatalogName('Malibu', 'ماليبو'),
    CatalogName('Equinox', 'إكوينوكس'),
    CatalogName('Tahoe', 'تاهو'),
    CatalogName('N300', 'إن ٣٠٠'),
  ],
  'Mitsubishi': [
    CatalogName('Lancer', 'لانسر'),
    CatalogName('Pajero', 'باجيرو'),
    CatalogName('Outlander', 'أوتلاندر'),
    CatalogName('ASX', 'إيه إس إكس'),
    CatalogName('L200', 'إل ٢٠٠'),
    CatalogName('Attrage', 'أتراج'),
    CatalogName('Xpander', 'إكسباندر'),
  ],
  'Suzuki': [
    CatalogName('Swift', 'سويفت'),
    CatalogName('Vitara', 'فيتارا'),
    CatalogName('Ciaz', 'سياز'),
    CatalogName('Ertiga', 'إرتيغا'),
    CatalogName('Jimny', 'جيمني'),
    CatalogName('Dzire', 'ديزاير'),
    CatalogName('Baleno', 'بالينو'),
    CatalogName('Alto', 'ألتو'),
  ],
  'Renault': [
    CatalogName('Logan', 'لوجان'),
    CatalogName('Sandero', 'سانديرو'),
    CatalogName('Megane', 'ميجان'),
    CatalogName('Duster', 'داستر'),
    CatalogName('Kadjar', 'كادجار'),
    CatalogName('Koleos', 'كوليوس'),
    CatalogName('Fluence', 'فلوانس'),
    CatalogName('Symbol', 'سيمبول'),
  ],
  'Peugeot': [
    CatalogName('208', '٢٠٨'),
    CatalogName('301', '٣٠١'),
    CatalogName('308', '٣٠٨'),
    CatalogName('2008', '٢٠٠٨'),
    CatalogName('3008', '٣٠٠٨'),
    CatalogName('5008', '٥٠٠٨'),
    CatalogName('508', '٥٠٨'),
    CatalogName('Partner', 'بارتنر'),
  ],
  'Citroen': [
    CatalogName('C3', 'سي ٣'),
    CatalogName('C4', 'سي ٤'),
    CatalogName('C5 Aircross', 'سي ٥ إيركروس'),
    CatalogName('Berlingo', 'برلينجو'),
  ],
  'Volkswagen': [
    CatalogName('Polo', 'بولو'),
    CatalogName('Golf', 'جولف'),
    CatalogName('Passat', 'باسات'),
    CatalogName('Tiguan', 'تيجوان'),
    CatalogName('Jetta', 'جيتا'),
    CatalogName('Touareg', 'طوارق'),
    CatalogName('T-Roc', 'تي روك'),
    CatalogName('ID.4', 'آي دي ٤'),
  ],
  'Skoda': [
    CatalogName('Octavia', 'أوكتافيا'),
    CatalogName('Rapid', 'رابيد'),
    CatalogName('Fabia', 'فابيا'),
    CatalogName('Superb', 'سوبيرب'),
    CatalogName('Kamiq', 'كاميك'),
    CatalogName('Karoq', 'كاروك'),
    CatalogName('Kodiaq', 'كودياك'),
  ],
  'BMW': [
    CatalogName('1 Series', 'الفئة الأولى'),
    CatalogName('3 Series', 'الفئة الثالثة'),
    CatalogName('5 Series', 'الفئة الخامسة'),
    CatalogName('7 Series', 'الفئة السابعة'),
    CatalogName('X1', 'إكس ون'),
    CatalogName('X3', 'إكس ثري'),
    CatalogName('X5', 'إكس فايف'),
    CatalogName('X6', 'إكس سيكس'),
  ],
  'Mercedes-Benz': [
    CatalogName('A-Class', 'فئة A'),
    CatalogName('C-Class', 'فئة C'),
    CatalogName('E-Class', 'فئة E'),
    CatalogName('S-Class', 'فئة S'),
    CatalogName('GLA', 'جي إل إيه'),
    CatalogName('GLC', 'جي إل سي'),
    CatalogName('GLE', 'جي إل إي'),
    CatalogName('G-Class', 'فئة G'),
  ],
  'Audi': [
    CatalogName('A3', 'إيه ٣'),
    CatalogName('A4', 'إيه ٤'),
    CatalogName('A6', 'إيه ٦'),
    CatalogName('Q3', 'كيو ٣'),
    CatalogName('Q5', 'كيو ٥'),
    CatalogName('Q7', 'كيو ٧'),
    CatalogName('Q8', 'كيو ٨'),
  ],
  'Mazda': [
    CatalogName('2', 'مازدا ٢'),
    CatalogName('3', 'مازدا ٣'),
    CatalogName('6', 'مازدا ٦'),
    CatalogName('CX-3', 'سي إكس ٣'),
    CatalogName('CX-5', 'سي إكس ٥'),
    CatalogName('CX-30', 'سي إكس ٣٠'),
    CatalogName('CX-9', 'سي إكس ٩'),
  ],
  'Ford': [
    CatalogName('Focus', 'فوكاس'),
    CatalogName('Fiesta', 'فييستا'),
    CatalogName('Escape', 'إسكيب'),
    CatalogName('EcoSport', 'إيكوسبورت'),
    CatalogName('Explorer', 'إكسبلورر'),
    CatalogName('Ranger', 'رينجر'),
    CatalogName('Edge', 'إيدج'),
    CatalogName('Mustang', 'موستنج'),
  ],
  'Jeep': [
    CatalogName('Wrangler', 'رانجلر'),
    CatalogName('Grand Cherokee', 'جراند شيروكي'),
    CatalogName('Compass', 'كومباس'),
    CatalogName('Renegade', 'رينيجيد'),
    CatalogName('Cherokee', 'شيروكي'),
  ],
  'MG': [
    CatalogName('5', 'إم جي ٥'),
    CatalogName('6', 'إم جي ٦'),
    CatalogName('ZS', 'زد إس'),
    CatalogName('HS', 'إتش إس'),
    CatalogName('RX5', 'آر إكس ٥'),
    CatalogName('GT', 'جي تي'),
  ],
  'Chery': [
    CatalogName('Arrizo', 'أريزو'),
    CatalogName('Tiggo 3', 'تيجو ٣'),
    CatalogName('Tiggo 4', 'تيجو ٤'),
    CatalogName('Tiggo 7', 'تيجو ٧'),
    CatalogName('Tiggo 8', 'تيجو ٨'),
  ],
  'BYD': [
    CatalogName('F3', 'إف ٣'),
    CatalogName('Song', 'سونج'),
    CatalogName('Seal', 'سيل'),
    CatalogName('Atto 3', 'أتو ٣'),
    CatalogName('Dolphin', 'دولفين'),
    CatalogName('Tang', 'تانج'),
  ],
  'Geely': [
    CatalogName('Emgrand', 'إمجراند'),
    CatalogName('Coolray', 'كولراي'),
    CatalogName('Preface', 'بريفيس'),
    CatalogName('Okavango', 'أوكافانجو'),
  ],
  'Changan': [
    CatalogName('Alsvin', 'ألسفين'),
    CatalogName('CS35', 'سي إس ٣٥'),
    CatalogName('CS55', 'سي إس ٥٥'),
    CatalogName('CS75', 'سي إس ٧٥'),
    CatalogName('Eado', 'إيدو'),
    CatalogName('UNI-T', 'يوني تي'),
  ],
  'Haval': [
    CatalogName('H6', 'إتش ٦'),
    CatalogName('Jolion', 'جوليون'),
    CatalogName('H9', 'إتش ٩'),
    CatalogName('Dargo', 'دارجو'),
  ],
  'Fiat': [
    CatalogName('Tipo', 'تيبو'),
    CatalogName('500', '٥٠٠'),
    CatalogName('Punto', 'بونتو'),
    CatalogName('Doblo', 'دوبلو'),
  ],
  'Opel': [
    CatalogName('Astra', 'أسترا'),
    CatalogName('Corsa', 'كورسا'),
    CatalogName('Insignia', 'إنسيجنيا'),
    CatalogName('Mokka', 'موكا'),
    CatalogName('Crossland', 'كروسلاند'),
  ],
  'Seat': [
    CatalogName('Ibiza', 'إبيزا'),
    CatalogName('Leon', 'ليون'),
    CatalogName('Ateca', 'أتيكا'),
    CatalogName('Arona', 'أرونا'),
  ],
  'Lexus': [
    CatalogName('IS', 'آي إس'),
    CatalogName('ES', 'إي إس'),
    CatalogName('RX', 'آر إكس'),
    CatalogName('NX', 'إن إكس'),
    CatalogName('LX', 'إل إكس'),
    CatalogName('UX', 'يو إكس'),
  ],
  'Infiniti': [
    CatalogName('Q50', 'كيو ٥٠'),
    CatalogName('QX50', 'كيو إكس ٥٠'),
    CatalogName('QX60', 'كيو إكس ٦٠'),
    CatalogName('QX80', 'كيو إكس ٨٠'),
  ],
  'Volvo': [
    CatalogName('S60', 'إس ٦٠'),
    CatalogName('S90', 'إس ٩٠'),
    CatalogName('XC40', 'إكس سي ٤٠'),
    CatalogName('XC60', 'إكس سي ٦٠'),
    CatalogName('XC90', 'إكس سي ٩٠'),
  ],
  'Land Rover': [
    CatalogName('Defender', 'ديفندر'),
    CatalogName('Discovery', 'ديسكفري'),
    CatalogName('Range Rover', 'رينج روفر'),
    CatalogName('Evoque', 'إيفوك'),
    CatalogName('Sport', 'سبورت'),
  ],
  'Mini': [
    CatalogName('Cooper', 'كوبر'),
    CatalogName('Countryman', 'كانتري مان'),
    CatalogName('Clubman', 'كلب مان'),
  ],
  'Tesla': [
    CatalogName('Model 3', 'موديل ٣'),
    CatalogName('Model Y', 'موديل واي'),
    CatalogName('Model S', 'موديل إس'),
    CatalogName('Model X', 'موديل إكس'),
  ],
  'Isuzu': [CatalogName('D-Max', 'دي ماكس'), CatalogName('MU-X', 'إم يو إكس')],
  'Daihatsu': [
    CatalogName('Terios', 'تيريوس'),
    CatalogName('Gran Max', 'جران ماكس'),
    CatalogName('Sirion', 'سيريون'),
  ],
  'Proton': [
    CatalogName('Saga', 'ساجا'),
    CatalogName('Persona', 'بيرسونا'),
    CatalogName('X50', 'إكس ٥٠'),
    CatalogName('X70', 'إكس ٧٠'),
  ],
  'Subaru': [
    CatalogName('Impreza', 'إمبريزا'),
    CatalogName('Forester', 'فورستر'),
    CatalogName('Outback', 'أوت باك'),
    CatalogName('XV', 'إكس في'),
    CatalogName('WRX', 'دبليو آر إكس'),
  ],
  'GAC': [
    CatalogName('GS3', 'جي إس ٣'),
    CatalogName('GS4', 'جي إس ٤'),
    CatalogName('GS8', 'جي إس ٨'),
    CatalogName('Empow', 'إمباو'),
  ],
  'Jetour': [
    CatalogName('X70', 'إكس ٧٠'),
    CatalogName('X90', 'إكس ٩٠'),
    CatalogName('Dashing', 'داشنغ'),
    CatalogName('T2', 'تي ٢'),
  ],
  'Porsche': [
    CatalogName('Cayenne', 'كايين'),
    CatalogName('Macan', 'ماكان'),
    CatalogName('911', '٩١١'),
    CatalogName('Panamera', 'باناميرا'),
  ],
  'Jaguar': [
    CatalogName('XE', 'إكس إي'),
    CatalogName('XF', 'إكس إف'),
    CatalogName('F-Pace', 'إف بيس'),
    CatalogName('E-Pace', 'إي بيس'),
  ],
};
