import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/crash_reporter.dart';
import '../storage/preferences_store.dart';
import 'remote_defaults.dart';

/// Fetches the published defaults, and remembers the last set that arrived.
///
/// **The cache is not an optimisation.** This document is read before the
/// driver has an account, often before they have a connection, and on a
/// platform where Firebase may not be configured at all. Every one of those is
/// a normal state, and in all of them the app still has to know what a litre of
/// 92 costs. So the last good copy is kept in preferences and served
/// immediately on the next launch, with the network fetch layered over it when
/// and if it lands.
///
/// Nothing here throws. A failed fetch means the cached copy stands, and a
/// cache that has never been written means the caller falls back to what the
/// binary shipped with — which is the same answer the app gave before any of
/// this existed.
class RemoteDefaultsRepository {
  const RemoteDefaultsRepository({
    required PreferencesStore preferences,
    FirebaseFirestore? firestore,
  }) : _prefs = preferences,
       _firestore = firestore;

  final PreferencesStore _prefs;

  /// Null where Firebase is not configured for this platform, which makes this
  /// repository cache-only rather than broken.
  final FirebaseFirestore? _firestore;

  /// Published at a fixed path, outside every workspace: it belongs to the app,
  /// not to any one driver. The security rules make it world-readable and
  /// nobody-writable — see `firestore.rules`.
  static const String collection = 'app_config';
  static const String document = 'defaults';

  /// The last set that arrived, or [RemoteDefaults.empty] on a device that has
  /// never successfully fetched one. Synchronous, so the first frame can use it.
  RemoteDefaults cached() {
    final raw = _prefs.remoteDefaults;
    if (raw == null || raw.isEmpty) return RemoteDefaults.empty;
    try {
      return RemoteDefaults.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stack) {
      // A cache this app wrote itself should always parse. If it does not, the
      // shape changed under a stored copy and every launch is quietly serving
      // nothing — worth a report precisely because it is invisible.
      CrashReporter.recordError(
        error,
        stack,
        reason: 'remote defaults cache unreadable',
      );
      return RemoteDefaults.empty;
    }
  }

  /// Reads the published document and caches it.
  ///
  /// Returns null when there is nothing new to apply: no Firebase, no network,
  /// no document, or a document that parsed to nothing. Null means "keep what
  /// you have", never "you have nothing".
  Future<RemoteDefaults?> fetch() async {
    final firestore = _firestore;
    if (firestore == null) return null;

    try {
      final snapshot = await firestore
          .collection(collection)
          .doc(document)
          // The server copy or nothing. Firestore would otherwise answer from
          // its own cache, which for this document is a slower, less complete
          // duplicate of the cache directly above.
          .get(const GetOptions(source: Source.server));

      final data = snapshot.data();
      if (data == null) return null;

      final defaults = RemoteDefaults.fromJson(data);
      if (defaults.isEmpty) return null;

      await _prefs.setRemoteDefaults(jsonEncode(defaults.toJson()));
      return defaults;
    } catch (error, stack) {
      // Offline is the common case here and is not worth a report; anything
      // else is. Neither is worth failing the launch over.
      CrashReporter.recordError(
        error,
        stack,
        reason: 'remote defaults fetch failed',
      );
      return null;
    }
  }
}
