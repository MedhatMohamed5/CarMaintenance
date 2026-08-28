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
}
