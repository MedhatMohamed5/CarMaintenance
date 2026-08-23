import 'dart:convert';
import 'dart:typed_data';

import '../../expenses/data/models/expense_model.dart';
import '../../fuel/data/models/fuel_log_model.dart';
import '../../fuel/domain/fuel_math.dart';
import '../../maintenance/data/models/maintenance_record_model.dart';
import '../../maintenance/data/models/part_replacement_model.dart';
import '../../maintenance/domain/entities/consumable_part.dart';
import '../../maintenance/domain/usecases/calculate_parts_health.dart';
import '../../maintenance/domain/usecases/predict_services.dart';
import '../domain/entities/vehicle.dart';
import '../domain/entities/vehicle_transfer_bundle.dart';
import '../domain/repositories/vehicle_transfer_codec.dart';
import 'models/vehicle_model.dart';

/// One vehicle's data as a standalone, human-readable JSON document.
///
/// It writes through the same `toJson`/`fromJson` the Hive boxes and Firestore
/// already share, so an exported file is the app's canonical shape rather than
/// a third serialisation nobody maintains.
class VehicleTransferJsonCodec implements VehicleTransferCodec {
  const VehicleTransferJsonCodec();

  /// Stamped into every document so a JSON file from somewhere else is
  /// rejected with a translated message instead of half-importing.
  static const String formatTag = 'vehicle_care.vehicle_transfer';
  static const int formatVersion = 2;

  static const String _keyVehicle = 'vehicle';
  static const String _keyRecords = 'maintenanceRecords';
  static const String _keyReplacements = 'partReplacements';
  static const String _keyFuelLogs = 'fuelLogs';
  static const String _keyExpenses = 'expenses';
  static const String _keyUpcoming = 'upcomingSchedule';
  static const String _keyWear = 'wearTargets';

  @override
  String get mimeType => 'application/json';

  @override
  List<String> get extensions => const ['json'];

  @override
  Uint8List encode(VehicleTransferBundle bundle) {
    final document = <String, dynamic>{
      'format': formatTag,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      _keyVehicle: VehicleModel.fromEntity(bundle.vehicle).toJson(),
      _keyRecords: [
        for (final r in bundle.records)
          MaintenanceRecordModel.fromEntity(r).toJson(),
      ],
      _keyReplacements: [
        for (final r in bundle.replacements)
          PartReplacementModel.fromEntity(r).toJson(),
      ],
      _keyFuelLogs: [
        for (final l in bundle.fuelLogs) FuelLogModel.fromEntity(l).toJson(),
      ],
      _keyExpenses: [
        for (final e in bundle.expenses) ExpenseModel.fromEntity(e).toJson(),
      ],
      // Derived snapshots: the file is self-describing for completed history
      // *and* the relative interval targets that history currently implies.
      // Import ignores them — records + partSettings reconstruct the same
      // chain — so a v1 file without these keys still round-trips.
      _keyUpcoming: _upcomingSnapshot(bundle),
      _keyWear: _wearSnapshot(bundle),
    };

    // Indented: this file is a backup a user may well open and read.
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
    );
  }

  @override
  VehicleTransferBundle decode(Uint8List bytes) {
    final Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const VehicleTransferException(VehicleTransferFailure.malformed);
    }

    if (parsed is! Map) {
      throw const VehicleTransferException(VehicleTransferFailure.malformed);
    }
    final document = Map<String, dynamic>.from(parsed);

    final tag = document['format'];
    if (tag is String && tag != formatTag) {
      throw const VehicleTransferException(VehicleTransferFailure.wrongFormat);
    }

    final version = document['version'];
    if (version is num && version > formatVersion) {
      throw const VehicleTransferException(
        VehicleTransferFailure.unsupportedVersion,
      );
    }

    final vehicleJson = document[_keyVehicle];
    if (vehicleJson is! Map) {
      throw const VehicleTransferException(VehicleTransferFailure.wrongFormat);
    }

    try {
      return VehicleTransferBundle(
        vehicle: VehicleModel.fromJson(_withId(vehicleJson, 'vehicle')),
        records: [
          for (final json in _entries(document[_keyRecords], 'record'))
            MaintenanceRecordModel.fromJson(json),
        ],
        replacements: [
          for (final json in _entries(document[_keyReplacements], 'part'))
            PartReplacementModel.fromJson(json),
        ],
        fuelLogs: [
          for (final json in _entries(document[_keyFuelLogs], 'fuel'))
            FuelLogModel.fromJson(json),
        ],
        expenses: [
          for (final json in _entries(document[_keyExpenses], 'expense'))
            ExpenseModel.fromJson(json),
        ],
      );
    } on VehicleTransferException {
      rethrow;
    } catch (_) {
      // Every model tolerates missing or oddly typed fields through `JsonX`,
      // so landing here means the document is structurally wrong rather than
      // merely incomplete.
      throw const VehicleTransferException(VehicleTransferFailure.malformed);
    }
  }

  @override
  String fileNameFor(Vehicle vehicle) {
    final slug = vehicle.displayName
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^\w\-]'), '');
    final stamp = DateTime.now().toIso8601String().split('T').first;
    // An Arabic-only nickname slugs down to nothing, and a file called
    // "vehicle-care--2026-01-01.json" reads like a bug.
    final name = slug.replaceAll('-', '').isEmpty ? 'vehicle' : slug;
    return 'vehicle-care-$name-$stamp.json';
  }

  /// The list at [value] as JSON maps, skipping anything that is not one.
  Iterable<Map<String, dynamic>> _entries(Object? value, String kind) {
    if (value is! List) return const [];
    var index = 0;
    return value.whereType<Map>().map(
      (entry) => _withId(entry, '$kind-${index++}'),
    );
  }

  /// Guarantees an `id`, because every model reads it as a required String.
  ///
  /// A hand-written or trimmed-down document is still worth importing: ids are
  /// regenerated on the way in regardless, so a synthesised placeholder costs
  /// nothing and a missing one would otherwise fail the whole file.
  Map<String, dynamic> _withId(Map<Object?, Object?> json, String fallbackId) {
    final map = <String, dynamic>{
      for (final entry in json.entries) '${entry.key}': entry.value,
    };
    if (map['id'] is! String) map['id'] = fallbackId;
    return map;
  }

  double _pace(VehicleTransferBundle bundle) {
    final logs = [...bundle.fuelLogs]..sort((a, b) => a.date.compareTo(b.date));
    if (logs.length < 2) return 0;
    return FuelMath.kmPerDay(
      distanceKm: FuelMath.distanceBetween(
        logs.first.odometer,
        logs.last.odometer,
      ),
      days: logs.last.date.difference(logs.first.date).inDays,
    );
  }

  List<Map<String, dynamic>> _upcomingSnapshot(VehicleTransferBundle bundle) {
    final roadmap = const PredictServices()(
      vehicle: bundle.vehicle,
      records: bundle.records,
      avgDailyKmFromFuel: _pace(bundle),
    );
    return [
      for (final stop in roadmap)
        {
          'phaseIndex': stop.milestone.phaseIndex,
          'targetOdometer': stop.milestone.targetOdometer,
          'tier': stop.milestone.tier.name,
          'isComplimentary': stop.milestone.isComplimentary,
          'kmRemaining': stop.kmRemaining,
          'isCompleted': stop.isCompleted,
          'estimatedDate': stop.estimatedDate?.toIso8601String(),
        },
    ];
  }

  List<Map<String, dynamic>> _wearSnapshot(VehicleTransferBundle bundle) {
    final health = const CalculatePartsHealth()(
      vehicle: bundle.vehicle,
      replacements: bundle.replacements,
      parts: ConsumablePart.dashboardOrder,
      avgDailyKm: _pace(bundle),
    );
    return [
      for (final item in health)
        {
          'part': item.part.id,
          'intervalKm': item.intervalKm,
          'intervalMonths': item.intervalMonths,
          'lastReplacedOdometer': item.lastReplacedOdometer,
          'distanceDriven': item.distanceDriven,
          'kmRemaining': item.remainingKm,
          'dueAtOdometer': item.dueAtOdometer,
          'rawWearFraction': item.rawWearFraction,
          'baselineSource': item.baselineSource.name,
          'lastReplacedDate': item.lastReplacedDate?.toIso8601String(),
          'estimatedDueDate': item.estimatedDueDate?.toIso8601String(),
          'limitedByTime': item.limitedByTime,
        },
    ];
  }
}
