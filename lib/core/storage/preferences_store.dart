import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<PreferencesStore> create() async =>
      PreferencesStore(await SharedPreferences.getInstance());

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
}
