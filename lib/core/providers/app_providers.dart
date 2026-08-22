import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../localization/app_localizations.dart';
import '../platform/link_launcher.dart';
import '../platform/reminder_notifier.dart';
import '../storage/preferences_store.dart';

/// Injected once in `main()` after `SharedPreferences` has loaded, so no
/// provider ever has to await settings.
final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => throw UnimplementedError(
    'preferencesStoreProvider must be overridden in ProviderScope',
  ),
);

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final notificationServiceProvider = Provider<ReminderNotifier>(
  (ref) => createReminderNotifier(),
);

final launcherServiceProvider = Provider<LinkLauncher>(
  (ref) => const UrlLauncherLink(),
);

// ── Theme ───────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(preferencesStoreProvider).themeMode;
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesStoreProvider).setThemeMode(mode.name);
  }

  /// Used by the app-bar toggle: flips between light and dark, resolving
  /// `system` against what is currently on screen.
  Future<void> toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Locale ──────────────────────────────────────────────────────────────────

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref.read(preferencesStoreProvider).localeCode;
    // Arabic is the primary audience, so it is the default rather than a
    // fallback the user has to go find.
    return Locale(stored ?? 'ar');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(preferencesStoreProvider).setLocaleCode(locale.languageCode);
  }

  Future<void> toggle() =>
      set(Locale(state.languageCode == 'ar' ? 'en' : 'ar'));
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Locale-aware string table available outside the widget tree (controllers,
/// notification bodies) where there is no `BuildContext`.
final l10nProvider = Provider<AppLocalizations>(
  (ref) => AppLocalizations(ref.watch(localeProvider)),
);

/// `intl` locale tag for the formatters.
final localeTagProvider = Provider<String>(
  (ref) => ref.watch(localeProvider).languageCode,
);

// ── Notifications toggle ────────────────────────────────────────────────────

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(preferencesStoreProvider).notificationsEnabled;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesStoreProvider).setNotificationsEnabled(value);
    if (value) {
      await ref.read(notificationServiceProvider).requestPermissions();
    } else {
      await ref.read(notificationServiceProvider).cancelAll();
    }
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
      NotificationsEnabledNotifier.new,
    );
