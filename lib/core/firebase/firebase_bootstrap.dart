import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum BackendMode {
  local,
  firestore;

  static BackendMode fromName(String? name) => BackendMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => BackendMode.local,
  );
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _available = false;

  static bool get isAvailable => _available;

  static Future<bool> tryInitialize({FirebaseOptions? options}) async {
    if (_available) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _available = true;
    } catch (e) {
      debugPrint('Firebase unavailable, staying local-only: $e');
      _available = false;
    }
    return _available;
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// The instance, or null when Firebase never came up here.
  ///
  /// [firestore] asserts an initialised app, which is right for every caller
  /// that only runs behind a signed-in check. The published-defaults read is
  /// not one of those: it happens on a fresh install, before any account, on
  /// desktop, and offline — so it needs to ask rather than assume.
  static FirebaseFirestore? get firestoreOrNull =>
      _available ? FirebaseFirestore.instance : null;
}

class FirestorePaths {
  const FirestorePaths(this.workspaceId, {FirebaseFirestore? firestore})
    : _firestore = firestore;

  final String workspaceId;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseBootstrap.firestore;

  DocumentReference<Map<String, dynamic>> get _root =>
      firestore.collection('workspaces').doc(workspaceId);

  CollectionReference<Map<String, dynamic>> get vehicles =>
      _root.collection('vehicles');

  CollectionReference<Map<String, dynamic>> get fuelLogs =>
      _root.collection('fuel_logs');

  CollectionReference<Map<String, dynamic>> get maintenance =>
      _root.collection('maintenance');

  CollectionReference<Map<String, dynamic>> get partReplacements =>
      _root.collection('part_replacements');

  CollectionReference<Map<String, dynamic>> get expenses =>
      _root.collection('expenses');

  CollectionReference<Map<String, dynamic>> get notes =>
      _root.collection('notes');

  /// The driver's own workshops: rows they added, and rows they edited on top
  /// of the published directory. Never the published directory itself — that
  /// is shared, lives outside every workspace, and nothing here writes to it.
  CollectionReference<Map<String, dynamic>> get workshops =>
      _root.collection('workshops');

  /// App-level preferences that belong to the account rather than the device —
  /// currently just the pump prices. One document per setting, so adding a
  /// second cannot make the first conflict.
  CollectionReference<Map<String, dynamic>> get settings =>
      _root.collection('settings');
}
