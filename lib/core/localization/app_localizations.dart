import 'package:flutter/material.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// Lightweight, dependency-free localisation layer.
///
/// Strings live in plain Dart maps ([kStringsAr] / [kStringsEn]) so adding a
/// language is a single file plus one entry in [supportedLocales] — no code
/// generation step in the build.
class AppLocalizations {
  AppLocalizations(this.locale)
    : _values = switch (locale.languageCode) {
        'ar' => kStringsAr,
        _ => kStringsEn,
      };

  final Locale locale;
  final Map<String, String> _values;

  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  bool get isArabic => locale.languageCode == 'ar';

  /// Raw lookup. Falls back to English, then to the key itself so a missing
  /// translation is visible rather than silently blank.
  String raw(String key) => _values[key] ?? kStringsEn[key] ?? key;

  /// Lookup with `{placeholder}` substitution.
  String fmt(String key, Map<String, Object?> args) {
    var out = raw(key);
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  // ── App shell ─────────────────────────────────────────────────────────────
  String get appTitle => raw('appTitle');
  String get tabHome => raw('tabHome');
  String get tabMaintenanceLog => raw('tabMaintenanceLog');
  String get tabSchedule => raw('tabSchedule');
  String get tabFuel => raw('tabFuel');
  String get tabExpenses => raw('tabExpenses');
  String get tabWorkshops => raw('tabWorkshops');
  String get settings => raw('settings');
  String get language => raw('language');
  String get themeMode => raw('themeMode');
  String get themeSystem => raw('themeSystem');
  String get themeLight => raw('themeLight');
  String get themeDark => raw('themeDark');
  String get notifications => raw('notifications');

  // ── Generic ───────────────────────────────────────────────────────────────
  String get save => raw('save');
  String get cancel => raw('cancel');
  String get delete => raw('delete');
  String get edit => raw('edit');
  String get add => raw('add');
  String get search => raw('search');
  String get all => raw('all');
  String get none => raw('none');
  String get today => raw('today');
  String get date => raw('date');
  String get notes => raw('notes');
  String get optional => raw('optional');
  String get required_ => raw('required');
  String get invalidNumber => raw('invalidNumber');
  String get km => raw('km');
  String get liter => raw('liter');
  String get currency => raw('currency');
  String get perKm => raw('perKm');
  String get kmPerLiter => raw('kmPerLiter');
  String get close => raw('close');
  String get saveChanges => raw('saveChanges');
  String get lPer100Km => raw('lPer100Km');
  String get fuelEconomy => raw('fuelEconomy');
  String get currentTank => raw('currentTank');
  String get runningCostPerKm => raw('runningCostPerKm');
  String get sinceLastFill => raw('sinceLastFill');
  String get displayMetric => raw('displayMetric');
  String get day => raw('day');
  String get days => raw('days');
  String get month => raw('month');
  String get months => raw('months');
  String get viewAll => raw('viewAll');
  String get confirmDelete => raw('confirmDelete');
  String get retry => raw('retry');
  String get somethingWentWrong => raw('somethingWentWrong');

  // ── Vehicles ──────────────────────────────────────────────────────────────
  String get vehicles => raw('vehicles');
  String get myVehicles => raw('myVehicles');
  String get addVehicle => raw('addVehicle');
  String get editVehicle => raw('editVehicle');
  String get make => raw('make');
  String get model => raw('model');
  String get year => raw('year');
  String get nickname => raw('nickname');
  String get plateNumber => raw('plateNumber');

  /// Fuel tank size — not engine displacement, which a bare "L" label was
  /// easily read as.
  String get tankCapacity => raw('tankCapacity');
  String get initialOdometer => raw('initialOdometer');

  /// Generic "reading at this entry", used by fuel, service and expense
  /// forms.
  String get currentOdometer => raw('currentOdometer');

  /// The vehicle's own live reading — distinct from [initialOdometer],
  /// which is the baseline it joined the app at.
  String get vehicleCurrentOdometer => raw('vehicleCurrentOdometer');
  String get updateOdometer => raw('updateOdometer');
  String get purchaseDate => raw('purchaseDate');
  String get licenseExpiry => raw('licenseExpiry');
  String get insuranceExpiry => raw('insuranceExpiry');
  String get noVehicles => raw('noVehicles');
  String get noVehiclesHint => raw('noVehiclesHint');
  String get switchVehicle => raw('switchVehicle');

  // ── Dashboard ─────────────────────────────────────────────────────────────
  String get dashboard => raw('dashboard');
  String get totalSpend => raw('totalSpend');
  String get thisMonth => raw('thisMonth');
  String get avgDaily => raw('avgDaily');
  String get avgMonthly => raw('avgMonthly');
  String get alerts => raw('alerts');
  String get noAlerts => raw('noAlerts');
  String get consumablesHealth => raw('consumablesHealth');
  String get documents => raw('documents');
  String get carInsurance => raw('carInsurance');
  String get carLicense => raw('carLicense');
  String get renewsOn => raw('renewsOn');
  String get remainingDays => raw('remainingDays');
  String get expired => raw('expired');
  String get fuelEfficiency => raw('fuelEfficiency');
  String get quickActions => raw('quickActions');
  String get lifespan => raw('lifespan');
  String get consumed => raw('consumed');
  String get remaining => raw('remaining');
  String get overdue => raw('overdue');
  String get dueSoon => raw('dueSoon');
  String get healthy => raw('healthy');

  // ── Fuel ──────────────────────────────────────────────────────────────────
  String get fuelLogs => raw('fuelLogs');
  String get addFuelEntry => raw('addFuelEntry');
  String get fuelType => raw('fuelType');
  String get fuelAmount => raw('fuelAmount');
  String get totalCost => raw('totalCost');
  String get pricePerLiter => raw('pricePerLiter');
  String get fullTank => raw('fullTank');
  String get fullTankHint => raw('fullTankHint');
  String get efficiency => raw('efficiency');
  String get costPerKm => raw('costPerKm');
  String get distance => raw('distance');
  String get bestEfficiency => raw('bestEfficiency');
  String get avgEfficiency => raw('avgEfficiency');
  String get octaneComparison => raw('octaneComparison');
  String get octaneComparisonHint => raw('octaneComparisonHint');
  String get noFuelLogs => raw('noFuelLogs');
  String get needsTwoFills => raw('needsTwoFills');
  String get octane92 => raw('octane92');
  String get octane95 => raw('octane95');
  String get diesel => raw('diesel');
  String get fuelTrend => raw('fuelTrend');

  // ── Maintenance ───────────────────────────────────────────────────────────
  String get maintenance => raw('maintenance');
  String get maintenanceHistory => raw('maintenanceHistory');
  String get logService => raw('logService');
  String get serviceType => raw('serviceType');
  String get workshop => raw('workshop');
  String get cost => raw('cost');
  String get partsReplaced => raw('partsReplaced');
  String get replaceAndChange => raw('replaceAndChange');
  String get inspectAndReview => raw('inspectAndReview');
  String get majorService => raw('majorService');
  String get minorService => raw('minorService');
  String get importantService => raw('importantService');
  String get nextService => raw('nextService');
  String get estimatedDate => raw('estimatedDate');
  String get upcomingServices => raw('upcomingServices');
  String get completedServices => raw('completedServices');
  String get serviceRoadmap => raw('serviceRoadmap');
  String get noMaintenanceLogs => raw('noMaintenanceLogs');
  String get markDone => raw('markDone');
  String get resetPart => raw('resetPart');
  String get resetPartHint => raw('resetPartHint');

  // ── Expenses ──────────────────────────────────────────────────────────────
  String get expenses => raw('expenses');
  String get addExpense => raw('addExpense');
  String get category => raw('category');
  String get amount => raw('amount');
  String get title => raw('title');
  String get noExpenses => raw('noExpenses');
  String get breakdown => raw('breakdown');
  String get catRepair => raw('catRepair');
  String get catAccessories => raw('catAccessories');
  String get catParking => raw('catParking');
  String get catFines => raw('catFines');
  String get catWash => raw('catWash');
  String get catTolls => raw('catTolls');
  String get catInsurance => raw('catInsurance');
  String get catLicense => raw('catLicense');
  String get catOther => raw('catOther');

  // ── Dealers & emergency ───────────────────────────────────────────────────
  String get workshopsAndDealers => raw('workshopsAndDealers');
  String get authorizedDealers => raw('authorizedDealers');
  String get addWorkshop => raw('addWorkshop');
  String get searchDealers => raw('searchDealers');
  String get call => raw('call');
  String get hotline => raw('hotline');
  String get openInMaps => raw('openInMaps');
  String get openingHours => raw('openingHours');
  String get rating => raw('rating');
  String get city => raw('city');
  String get address => raw('address');
  String get phone => raw('phone');
  String get services => raw('services');
  String get noDealers => raw('noDealers');
  String get emergency => raw('emergency');
  String get emergencyNumbers => raw('emergencyNumbers');
  String get safetyTips => raw('safetyTips');
  String get couldNotLaunch => raw('couldNotLaunch');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
