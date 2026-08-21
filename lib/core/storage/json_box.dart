import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../error/failure.dart';

/// Generic offline-first CRUD store over a Hive box of JSON strings.
///
/// Every feature builds its local data source on top of this, so caching
/// semantics (write-through, reactive reads, id-keyed access) are identical
/// everywhere and only the mapping functions differ.
class JsonBox<T> {
  JsonBox({
    required this.boxName,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
  });

  final String boxName;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T value) toJson;
  final String Function(T value) idOf;

  Box<String> get _box => Hive.box<String>(boxName);

  T _decode(String raw) => fromJson(jsonDecode(raw) as Map<String, dynamic>);

  List<T> readAll() {
    try {
      return _box.values.map(_decode).toList(growable: false);
    } catch (e) {
      throw CacheFailure('Failed to read $boxName', cause: e);
    }
  }

  T? readById(String id) {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw);
  }

  Future<void> put(T value) async {
    try {
      await _box.put(idOf(value), jsonEncode(toJson(value)));
    } catch (e) {
      throw CacheFailure('Failed to write to $boxName', cause: e);
    }
  }

  Future<void> putAll(Iterable<T> values) async {
    try {
      await _box.putAll({
        for (final v in values) idOf(v): jsonEncode(toJson(v)),
      });
    } catch (e) {
      throw CacheFailure('Failed to write to $boxName', cause: e);
    }
  }

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();

  bool get isEmpty => _box.isEmpty;

  /// Emits the full list on every mutation — the shape Riverpod stream
  /// providers want, and cheap because these collections stay small.
  Stream<List<T>> watchAll() async* {
    yield readAll();
    yield* _box.watch().map((_) => readAll());
  }
}
