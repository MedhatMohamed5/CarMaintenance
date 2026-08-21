/// Tolerant JSON coercion shared by every model.
///
/// The same document can arrive from Hive (ISO strings), from Firestore
/// (`Timestamp` objects) or from a bundled asset (plain numbers), so parsing
/// stays deliberately forgiving rather than throwing on a type mismatch.
class JsonX {
  const JsonX._();

  static DateTime? date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return _viaToDate(value);
  }

  static DateTime dateOr(Object? value, DateTime fallback) =>
      date(value) ?? fallback;

  static int intOr(Object? value, int fallback) => switch (value) {
    num n => n.toInt(),
    String s => int.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static double doubleOr(Object? value, double fallback) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static double? doubleOrNull(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };

  static bool boolOr(Object? value, bool fallback) => switch (value) {
    bool b => b,
    num n => n != 0,
    String s => s.toLowerCase() == 'true',
    _ => fallback,
  };

  static List<String> stringList(Object? value) => switch (value) {
    Iterable<dynamic> it => it.map((e) => '$e').toList(growable: false),
    _ => const <String>[],
  };

  static Map<String, int> intMap(Object? value) => switch (value) {
    Map<dynamic, dynamic> m => {
      for (final e in m.entries) '${e.key}': intOr(e.value, 0),
    },
    _ => const <String, int>{},
  };

  /// Unwraps a Firestore `Timestamp` without taking a dependency on
  /// `cloud_firestore` in the shared code.
  static DateTime? _viaToDate(dynamic value) {
    try {
      final result = value.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }

  /// Parses an enum-ish string back to a value of [values] by its `name`,
  /// falling back to [fallback] for unknown or legacy values.
  static T enumByName<T extends Enum>(
    Object? value,
    List<T> values,
    T fallback,
  ) {
    final name = value is String ? value : null;
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
