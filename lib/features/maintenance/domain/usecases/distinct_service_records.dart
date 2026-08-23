import '../entities/maintenance_record.dart';

/// Collapses service history to one record per periodic phase.
///
/// A phase can legitimately be logged more than once (a correction, a
/// re-visit, a double submit). Only the most recent entry represents the
/// phase, so cost aggregation must count exactly one of them — otherwise the
/// same 20,000 km service is billed twice into Total Spend. Matching is done
/// on [MaintenanceRecord.resolvedMilestonePhase] rather than the odometer it
/// was logged against, because that odometer is a dynamic projection that
/// moves as earlier phases drift — two logs of the same phase can easily
/// carry two different `milestoneOdometer` values.
///
/// Ad-hoc records (no resolvable phase) are never collapsed: two unrelated
/// repairs at the same odometer are two real costs.
class DistinctServiceRecords {
  const DistinctServiceRecords();

  List<MaintenanceRecord> call(List<MaintenanceRecord> records) {
    final byPhase = <int, MaintenanceRecord>{};
    final adHoc = <MaintenanceRecord>[];

    for (final record in records) {
      final phase = record.resolvedMilestonePhase;
      if (phase == null) {
        adHoc.add(record);
        continue;
      }
      final existing = byPhase[phase];
      if (existing == null || _isNewer(record, existing)) {
        byPhase[phase] = record;
      }
    }

    final merged = [...byPhase.values, ...adHoc]
      ..sort((a, b) => b.odometer.compareTo(a.odometer));
    return List.unmodifiable(merged);
  }

  /// Later date wins; on a tie the higher odometer is the later visit.
  static bool _isNewer(MaintenanceRecord a, MaintenanceRecord b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate > 0;
    return a.odometer > b.odometer;
  }
}
