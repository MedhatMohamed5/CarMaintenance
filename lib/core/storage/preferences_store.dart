import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The locale and theme the app should paint with, resolved before any widget
/// exists.
///
/// The splash renders before the [ProviderScope] can be built, so it cannot
/// read `localeProvider`. Without this it fell back to a hardcoded default and
/// an English user watched an Arabic splash flip to English a second later.
class AppearancePreference {
  const AppearancePreference({required this.locale, required this.themeMode});

  final Locale locale;
  final ThemeMode themeMode;
}

/// Small key/value settings that are not domain data: theme mode, locale and
/// which vehicle the user last had selected.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'pref_theme_mode';
  static const _kLocale = 'pref_locale';
  static const _kSelectedVehicle = 'pref_selected_vehicle';
  static const _kNotificationsEnabled = 'pref_notifications_enabled';
  static const _kSeeded = 'pref_dealers_seeded';
  static const _kBackend = 'pref_backend_mode';
  static const _kWorkspace = 'pref_workspace_id';
  static const _kPriceBook = 'pref_price_book';
  static const _kFuelMetric = 'pref_fuel_metric';
  static const _kParking = 'pref_parking_location';
  static const _kDefaultFuelPrice = 'pref_default_fuel_price_per_liter';
  static const _kDefaultFuelPrices = 'pref_default_fuel_prices';

  /// Versioned on purpose. A future revision of the tour — new steps, a
  /// reordered dashboard — bumps the suffix and everyone sees it once more,
  /// without a migration and without replaying the old one.
  static const _kTourSeen = 'pref_tour_seen_v1';

  /// Separate from [notificationsEnabled] on purpose. A standing fortnightly
  /// nag is the one reminder a driver may want gone while still wanting to hear
  /// about an overdue service, and folding the two together would have them
  /// silence everything to stop one.
  static const _kRoutineChecks = 'pref_routine_checks_enabled';

  static const _kDealerRatings = 'pref_dealer_ratings';

  static Future<PreferencesStore> create() async =>
      PreferencesStore(await SharedPreferences.getInstance());

  /// Reads just enough to paint the first frame correctly.
  ///
  /// `SharedPreferences.getInstance()` caches its instance, so the full
  /// [create] later in the bootstrap costs nothing extra. Falls back to the
  /// app defaults — Arabic, dark — if the store cannot be opened at all, which
  /// is the same answer the providers give.
  static Future<AppearancePreference> restoreAppearance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppearancePreference(
        locale: resolveLocale(prefs.getString(_kLocale)),
        themeMode: resolveThemeMode(prefs.getString(_kThemeMode)),
      );
    } on Object {
      return const AppearancePreference(
        locale: Locale('ar'),
        themeMode: ThemeMode.dark,
      );
    }
  }

  /// The single place a stored language code becomes a [Locale]. Arabic is the
  /// primary audience, so it is the default rather than a fallback the user has
  /// to go find.
  static Locale resolveLocale(String? code) => Locale(code ?? 'ar');

  /// The single place a stored theme name becomes a [ThemeMode].
  ///
  /// **Matched against `ThemeMode.values`, not a hand-written list of arms.**
  /// This used to switch on `'light'` and `'dark'` and send everything else to
  /// the default — including `'system'`, which `set` writes as `mode.name` and
  /// stores perfectly well. The choice survived the write and died on the next
  /// launch, so "follow the system" came back as dark on every restart no
  /// matter what the phone was set to. Reading the arms off the enum means a
  /// member cannot be written but not read, which is the same shape
  /// `FuelMetric.fromName` and `BackendMode.fromName` already use.
  ///
  /// The default stays dark and now applies only where it should: a name that
  /// was never written — a first run, or a value from a build that no longer
  /// exists.
  static ThemeMode resolveThemeMode(String? name) => ThemeMode.values
      .firstWhere((m) => m.name == name, orElse: () => ThemeMode.dark);

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String v) => _prefs.setString(_kLocale, v);

  String? get selectedVehicleId => _prefs.getString(_kSelectedVehicle);
  Future<void> setSelectedVehicleId(String? v) => v == null
      ? _prefs.remove(_kSelectedVehicle)
      : _prefs.setString(_kSelectedVehicle, v);

  bool get notificationsEnabled =>
      _prefs.getBool(_kNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool v) =>
      _prefs.setBool(_kNotificationsEnabled, v);

  bool get dealersSeeded => _prefs.getBool(_kSeeded) ?? false;
  Future<void> setDealersSeeded(bool v) => _prefs.setBool(_kSeeded, v);

  String? get backendMode => _prefs.getString(_kBackend);
  Future<void> setBackendMode(String v) => _prefs.setString(_kBackend, v);

  String? get workspaceId => _prefs.getString(_kWorkspace);
  Future<void> setWorkspaceId(String v) => _prefs.setString(_kWorkspace, v);

  String? get priceBook => _prefs.getString(_kPriceBook);
  Future<void> setPriceBook(String v) => _prefs.setString(_kPriceBook, v);

  /// The one saved parking pin, as encoded JSON.
  ///
  /// A single slot rather than a list: the app pins where the car is now, and
  /// a spot you have already walked back to is not worth keeping.
  String? get parkingLocation => _prefs.getString(_kParking);
  Future<void> setParkingLocation(String? v) => v == null || v.isEmpty
      ? _prefs.remove(_kParking)
      : _prefs.setString(_kParking, v);

  /// Whether the guided tour of the dashboard has already run.
  bool get tourSeen => _prefs.getBool(_kTourSeen) ?? false;
  Future<void> setTourSeen(bool v) => _prefs.setBool(_kTourSeen, v);

  bool get routineChecksEnabled => _prefs.getBool(_kRoutineChecks) ?? true;
  Future<void> setRoutineChecksEnabled(bool v) =>
      _prefs.setBool(_kRoutineChecks, v);

  /// Workshop ratings given on this device, as encoded JSON.
  ///
  /// Device-local and never synced: the app is a directory, not a review
  /// platform, and one person's taps are not a score to publish. Kept here
  /// rather than on the workshop row because the standard directory is no
  /// longer stored at all — see `DealerRatings`.
  String? get dealerRatings => _prefs.getString(_kDealerRatings);
  Future<void> setDealerRatings(String v) =>
      _prefs.setString(_kDealerRatings, v);

  String? get fuelMetric => _prefs.getString(_kFuelMetric);
  Future<void> setFuelMetric(String v) => _prefs.setString(_kFuelMetric, v);

  /// Per-grade pump prices used to pre-fill new fuel entries.
  ///
  /// A device that only ever stored the older single rate still resolves: that
  /// figure is copied onto every grade until the user sets them individually.
  Map<String, double> get defaultFuelPrices {
    final stored = _decodePriceMap(_prefs.getString(_kDefaultFuelPrices));
    if (stored.isNotEmpty) return stored;
    final legacy = _prefs.getDouble(_kDefaultFuelPrice);
    if (legacy == null || legacy <= 0 || !legacy.isFinite) return const {};
    return {'octane92': legacy, 'octane95': legacy, 'diesel': legacy};
  }

  Future<void> setDefaultFuelPrices(Map<String, double> prices) {
    final cleaned = <String, double>{
      for (final entry in prices.entries)
        if (entry.value > 0 && entry.value.isFinite) entry.key: entry.value,
    };
    if (cleaned.isEmpty) return _prefs.remove(_kDefaultFuelPrices);
    return _prefs.setString(_kDefaultFuelPrices, jsonEncode(cleaned));
  }

  static Map<String, double> _decodePriceMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final prices = <String, double>{};
      for (final entry in decoded.entries) {
        final value = switch (entry.value) {
          num n => n.toDouble(),
          String s => double.tryParse(s),
          _ => null,
        };
        if (value != null && value > 0 && value.isFinite) {
          prices['${entry.key}'] = value;
        }
      }
      return prices;
    } on Object {
      return const {};
    }
  }
}
