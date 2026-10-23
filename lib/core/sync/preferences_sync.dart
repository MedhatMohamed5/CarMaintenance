import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/domain/reminder_category.dart';
import '../../features/dashboard/presentation/providers/reminder_prefs.dart';
import '../../features/fuel/domain/entities/fuel_metric.dart';
import '../../features/fuel/presentation/providers/fuel_providers.dart';
import '../firebase/firebase_bootstrap.dart';
import '../firebase/offline_write.dart';
import '../providers/app_providers.dart';
import '../providers/backend_providers.dart';
import '../providers/deferred_state.dart';
import '../storage/preferences_store.dart';

/// The settings that follow the driver from device to device: theme,
/// language, fuel-efficiency unit, and which reminders arrive at what hour.
///
/// One document, merged field by field, so changing the theme on one phone
/// cannot overwrite a reminder change made on another. The notifications
/// master switch stays per device: Android grants the permission per phone.
class FirestoreAccountPreferences {
  const FirestoreAccountPreferences(this._paths);

  final FirestorePaths _paths;

  static const String document = 'preferences';

  DocumentReference<Map<String, dynamic>> get _doc =>
      _paths.settings.doc(document);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch() => _doc.snapshots();

  Future<void> save(Map<String, Object?> fields) => fireAndForget(
    _doc.set({
      ...fields,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true)),
    label: 'account preferences',
  );
}

/// This account's settings document, or null when signed out.
final accountPreferencesStoreProvider = Provider<FirestoreAccountPreferences?>((
  ref,
) {
  if (!ref.watch(isRemoteBackendProvider)) return null;
  return FirestoreAccountPreferences(ref.watch(firestorePathsProvider));
});

/// Writes [fields] to the account when signed in; a no-op otherwise.
void pushPreferences(Ref ref, Map<String, Object?> fields) =>
    ref.read(accountPreferencesStoreProvider)?.save(fields);

/// Keeps this device's settings in step with the account's while signed in.
///
/// **The account wins.** Signing in brings that account's theme, language and
/// reminder choices onto the device, and a change made on another device
/// arrives here as it happens. Only an account that has never stored any —
/// its first sign-in — takes this device's settings instead. That is decided
/// on the server's answer, never on an empty offline cache, which would
/// otherwise overwrite an account it simply had not downloaded yet.
///
/// Watched from the app root so the binding lives as long as the session.
final preferencesSyncProvider = Provider<void>((ref) {
  final store = ref.watch(accountPreferencesStoreProvider);
  if (store == null) return;

  bindStream<DocumentSnapshot<Map<String, dynamic>>>(
    ref: ref,
    stream: store.watch(),
    source: 'preferences',
    assign: (snapshot) {
      final data = snapshot.data();
      if (data != null) {
        _apply(ref, data);
      } else if (!snapshot.metadata.isFromCache) {
        store.save(_current(ref));
      }
    },
  );
});

Map<String, Object?> _current(Ref ref) {
  final reminders = ref.read(reminderPrefsProvider);
  return {
    'themeMode': ref.read(themeModeProvider).name,
    'locale': ref.read(localeProvider).languageCode,
    'fuelMetric': ref.read(fuelMetricProvider).name,
    'reminderHour': reminders.hour,
    'remindersDisabled': [for (final c in reminders.disabled) c.name],
  };
}

/// Lays the account's values over the device's, without writing them back.
/// A field the document does not have yet leaves the device's value alone.
void _apply(Ref ref, Map<String, dynamic> data) {
  if (data['themeMode'] case final String name) {
    final mode = PreferencesStore.resolveThemeMode(name);
    if (mode != ref.read(themeModeProvider)) {
      ref.read(themeModeProvider.notifier).set(mode, push: false);
    }
  }
  if (data['locale'] case final String code) {
    final locale = PreferencesStore.resolveLocale(code);
    if (locale != ref.read(localeProvider)) {
      ref.read(localeProvider.notifier).set(locale, push: false);
    }
  }
  if (data['fuelMetric'] case final String name) {
    ref
        .read(fuelMetricProvider.notifier)
        .select(FuelMetric.fromName(name), push: false);
  }
  final reminders = ref.read(reminderPrefsProvider.notifier);
  if (data['reminderHour'] case final int hour) {
    reminders.setHour(hour, push: false);
  }
  if (data['remindersDisabled'] case final List<dynamic> names) {
    reminders.setDisabled({
      for (final c in ReminderCategory.toggleable)
        if (names.contains(c.name)) c,
    }, push: false);
  }
}
