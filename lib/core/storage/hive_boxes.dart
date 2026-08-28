import 'package:hive_ce_flutter/hive_flutter.dart';

/// Names of every Hive box in the app, plus the one-shot opener called from
/// `main()` before the widget tree is built.
///
/// Every box stores **JSON strings** rather than generated TypeAdapters. That
/// keeps a single serialisation path shared with Firestore (`toJson`/
/// `fromJson`), removes the build_runner step entirely, and makes a future
/// remote sync a straight pass-through of the same maps.
class HiveBoxes {
  const HiveBoxes._();

  static const String vehicles = 'box_vehicles';
  static const String fuelLogs = 'box_fuel_logs';
  static const String maintenance = 'box_maintenance';
  static const String partReplacements = 'box_part_replacements';
  static const String expenses = 'box_expenses';
  static const String dealers = 'box_dealers';
  static const String notes = 'box_notes';
  static const String meta = 'box_meta';

  static const List<String> all = [
    vehicles,
    fuelLogs,
    maintenance,
    partReplacements,
    expenses,
    dealers,
    notes,
    meta,
  ];

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final name in all) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<String>(name);
      }
    }
  }

  static Box<String> box(String name) => Hive.box<String>(name);
}
