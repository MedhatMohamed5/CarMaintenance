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
  static ThemeMode resolveThemeMode(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.dark,
  };

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

  String? get fuelMetric => _prefs.getString(_kFuelMetric);
  Future<void> setFuelMetric(String v) => _prefs.setString(_kFuelMetric, v);
}
