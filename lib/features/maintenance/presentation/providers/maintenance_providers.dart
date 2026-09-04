import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/deferred_state.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../fuel/domain/fuel_math.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/next_service_due.dart';
import '../../domain/entities/part_health.dart';
import '../../domain/entities/part_replacement.dart';
import '../../domain/entities/part_setting.dart';
import '../../domain/entities/service_milestone.dart';
import '../../domain/entities/upcoming_service.dart';
import '../../domain/usecases/distinct_service_records.dart';
import 'maintenance_repository_providers.dart';

export 'maintenance_repository_providers.dart';

class MaintenanceRecordsNotifier extends Notifier<List<MaintenanceRecord>> {
  @override
  List<MaintenanceRecord> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(maintenanceRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<MaintenanceRecord>>(
        ref: ref,
        stream: repository.watchRecords(vehicleId),
        assign: (items) => state = _sorted(items),
      );
    }

    return _sorted(repository.getRecords(vehicleId));
  }

  static List<MaintenanceRecord> _sorted(List<MaintenanceRecord> items) =>
      [...items]..sort((a, b) => b.odometer.compareTo(a.odometer));

  /// Re-reads this vehicle's history in place, for writes that went straight
  /// to the repository — a bulk import, say. Preferred over `ref.invalidate`,
  /// which tears the provider down mid-cascade.
  void reload() {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return;
    state = _sorted(
      ref.read(maintenanceRepositoryProvider).getRecords(vehicleId),
    );
  }

  Future<void> upsert(MaintenanceRecord record) async {
    await ref.read(maintenanceRepositoryProvider).saveService(record);
    state = _sorted([...state.where((r) => r.id != record.id), record]);
    ref.read(partReplacementsProvider.notifier).reload();
  }

  Future<void> remove(String id) async {
    await ref.read(maintenanceRepositoryProvider).deleteRecord(id);
    state = state.where((r) => r.id != id).toList(growable: false);
    ref.read(partReplacementsProvider.notifier).reload();
  }
}

/// Every entry for the selected vehicle, booked and completed alike.
///
/// **Almost nothing should read this.** It exists for the log screen, which
/// renders both, and for the reminder scheduler, which needs the bookings.
/// Anything that means "what has this car had done" wants
/// [completedRecordsProvider] — see the note there.
final maintenanceRecordsProvider =
    NotifierProvider<MaintenanceRecordsNotifier, List<MaintenanceRecord>>(
      MaintenanceRecordsNotifier.new,
    );

/// The history: entries whose work actually happened.
///
/// **This is the list every projection, cost and milestone must use.** A
/// booking carries a phase, an odometer and a cost the same way a completed
/// service does, and feeding it to the schedule would close the milestone it is
/// booked *for* — the car would be told its 40,000 km service was done because
/// an appointment for it exists. Same for spend, which would bill an intention,
/// and for the last-service date every projection is anchored on.
final completedRecordsProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref
      .watch(maintenanceRecordsProvider)
      .where((r) => r.isCompleted)
      .toList(growable: false),
);

/// Appointments that have not been confirmed as done, soonest first.
///
/// Ascending by date, unlike history: a booking is read forwards — what is
/// coming next — where a log is read backwards.
final scheduledRecordsProvider = Provider<List<MaintenanceRecord>>((ref) {
  final booked = ref
      .watch(maintenanceRecordsProvider)
      .where((r) => r.isScheduled)
      .toList();
  booked.sort(
    (a, b) => (a.scheduledDate ?? a.date).compareTo(b.scheduledDate ?? b.date),
  );
  return List<MaintenanceRecord>.unmodifiable(booked);
});

class PartReplacementsNotifier extends Notifier<List<PartReplacement>> {
  @override
  List<PartReplacement> build() {
    final vehicleId = ref.watch(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return const [];

    final repository = ref.watch(maintenanceRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {
      bindStream<List<PartReplacement>>(
        ref: ref,
        stream: repository.watchReplacements(vehicleId),
        assign: (items) => state = items,
      );
    }

    return repository.getReplacements(vehicleId);
  }

  /// Re-reads replacements in place. Preferred over `ref.invalidate`, which
  /// tears the provider down mid-cascade and can re-enter its build.
  void reload() {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return;
    state = ref.read(maintenanceRepositoryProvider).getReplacements(vehicleId);
  }

  Future<void> resetPart({
    required String vehicleId,
    required ConsumablePart part,
    required int odometer,
  }) async {
    await ref
        .read(maintenanceRepositoryProvider)
        .resetPart(vehicleId: vehicleId, part: part, odometer: odometer);
    state = ref.read(maintenanceRepositoryProvider).getReplacements(vehicleId);
  }
}

final partReplacementsProvider =
    NotifierProvider<PartReplacementsNotifier, List<PartReplacement>>(
      PartReplacementsNotifier.new,
    );

final partsHealthProvider = Provider<List<PartHealth>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(calculatePartsHealthProvider)(
    vehicle: vehicle,
    replacements: ref.watch(partReplacementsProvider),
    avgDailyKm: ref.watch(avgDailyKmProvider),
  );
});

final allPartsHealthProvider = Provider<List<PartHealth>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(calculatePartsHealthProvider)(
    vehicle: vehicle,
    replacements: ref.watch(partReplacementsProvider),
    parts: ConsumablePart.values,
    avgDailyKm: ref.watch(avgDailyKmProvider),
  );
});

/// Records grouped by the phase they close.
///
/// Its own provider because three separate consumers used to derive it: the
/// roadmap, the next-due card and every controller that closes a milestone.
/// Grouping the whole history three times per dashboard build is work nobody
/// asked for, and a `Provider` caches it until the records themselves change.
final serviceRecordsByPhaseProvider = Provider<Map<int, MaintenanceRecord>>(
  (ref) => ref
      .watch(predictServicesProvider)
      .recordsByPhase(ref.watch(completedRecordsProvider)),
);

final serviceRoadmapProvider = Provider<List<UpcomingService>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];
  return ref.watch(predictServicesProvider)(
    vehicle: vehicle,
    records: ref.watch(completedRecordsProvider),
    // Both already memoised; the engine would otherwise recompute them here.
    pace: ref.watch(dailyPaceProvider),
    phaseRecords: ref.watch(serviceRecordsByPhaseProvider),
  );
});

final nextServiceDueProvider = Provider<NextServiceDue?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;
  return ref
      .watch(predictServicesProvider)
      .nextDue(
        vehicle: vehicle,
        records: ref.watch(completedRecordsProvider),
        // The pace, the phase grouping and the last service are all already
        // computed elsewhere on this screen. Passing them in is the difference
        // between the dashboard walking the history once and walking it three
        // times.
        pace: ref.watch(dailyPaceProvider),
        phaseRecords: ref.watch(serviceRecordsByPhaseProvider),
        lastService: ref.watch(lastServiceProvider),
      );
});

final lastServiceProvider = Provider<MaintenanceRecord?>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return null;
  return ref
      .watch(predictServicesProvider)
      .lastPerformed(ref.watch(completedRecordsProvider), vehicle.id);
});

final distinctServiceRecordsProvider = Provider<DistinctServiceRecords>(
  (ref) => const DistinctServiceRecords(),
);

/// Service history with one entry per periodic phase — the list every cost
/// calculation must use.
final billableServiceRecordsProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref.watch(distinctServiceRecordsProvider)(
    ref.watch(completedRecordsProvider),
  ),
);

/// Planned work only — the four preventive tiers.
final scheduledServiceRecordsProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref
      .watch(billableServiceRecordsProvider)
      .where((r) => r.tier.isScheduled)
      .toList(growable: false),
);

/// Unscheduled repairs: breakdowns and faults, not roadmap stops.
final correctiveRecordsProvider = Provider<List<MaintenanceRecord>>(
  (ref) => ref
      .watch(billableServiceRecordsProvider)
      .where((r) => r.tier.isCorrective)
      .toList(growable: false),
);

/// What the periodic schedule has cost.
///
/// **Repairs are excluded and reported separately.** Folding a gearbox failure
/// into "maintenance" makes the schedule look expensive and hides the thing the
/// driver actually wants to see — whether this car breaks. They are two
/// different questions about a car and they deserve two numbers.
final scheduledServiceSpendProvider = Provider<double>(
  (ref) => ref
      .watch(scheduledServiceRecordsProvider)
      .fold<double>(0, (sum, r) => sum + r.cost),
);

/// What breakdowns have cost.
final correctiveSpendProvider = Provider<double>(
  (ref) => ref
      .watch(correctiveRecordsProvider)
      .fold<double>(0, (sum, r) => sum + r.cost),
);

/// Money spent on consumable parts fitted **outside** a logged service.
///
/// A replacement derived from a service carries no cost of its own — its price
/// is already inside that record's total — so counting every replacement would
/// bill the same brake pads twice. Only standalone entries, the ones a user
/// created by resetting a part directly, are summed here.
final partsSpendProvider = Provider<double>(
  (ref) => ref
      .watch(partReplacementsProvider)
      .where((r) => r.maintenanceRecordId == null)
      .fold<double>(0, (sum, r) => sum + (r.cost ?? 0)),
);

final upcomingServicesProvider = Provider<List<UpcomingService>>(
  (ref) => ref
      .watch(serviceRoadmapProvider)
      .where((s) => !s.isCompleted)
      .take(3)
      .toList(growable: false),
);

final dailyPaceProvider = Provider<double>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return 0;
  return ref
      .watch(predictServicesProvider)
      .dailyPace(
        vehicle: vehicle,
        avgDailyKmFromFuel: ref.watch(avgDailyKmProvider),
      );
});

final monthlyPaceProvider = Provider<double>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return 0;

  final fuel = ref.watch(fuelStatsProvider);
  var start = vehicle.createdAt;
  var end = vehicle.odometerUpdatedAt ?? DateTime.now();
  final firstLog = fuel.firstLogDate;
  final lastLog = fuel.lastLogDate;
  if (firstLog != null && firstLog.isBefore(start)) start = firstLog;
  if (lastLog != null && lastLog.isAfter(end)) end = lastLog;
  final now = DateTime.now();
  if (now.isAfter(end)) end = now;

  return FuelMath.kmPerMonth(
    distanceKm: vehicle.trackedDistanceKm,
    days: DateX.daysBetween(start, end),
  );
});

/// Edits one part's baseline without logging a full service.
class PartSettingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Odometer reading at the part's last change.
  Future<bool> setLastReplacedOdometer(
    ConsumablePart part,
    int odometer, {
    DateTime? date,
  }) => _update(
    part,
    (setting) => setting.copyWith(
      lastReplacedOdometer: odometer < 0 ? 0 : odometer,
      lastReplacedDate: date,
      clearCustomWear: true,
    ),
  );

  /// "KM driven on current part" — converted to a baseline against the
  /// vehicle's current reading.
  Future<bool> setDistanceDriven(ConsumablePart part, int kmDriven) {
    final vehicle = ref.read(selectedVehicleProvider);
    if (vehicle == null) return Future.value(false);
    final baseline = vehicle.currentOdometer - (kmDriven < 0 ? 0 : kmDriven);
    return setLastReplacedOdometer(part, baseline < 0 ? 0 : baseline);
  }

  Future<bool> setInterval(ConsumablePart part, int intervalKm) => _update(
    part,
    (setting) => setting.copyWith(intervalKm: intervalKm <= 0 ? 1 : intervalKm),
  );

  /// Pins wear directly, e.g. a used part known to be half worn.
  Future<bool> setCustomWear(ConsumablePart part, double wearFraction) =>
      _update(
        part,
        (setting) => setting.copyWith(
          customWear: wearFraction.clamp(0.0, 10.0),
          clearBaseline: true,
        ),
      );

  /// Drops every override, returning the part to logged/inferred history.
  Future<bool> reset(ConsumablePart part) =>
      _update(part, (_) => const PartSetting());

  Future<bool> _update(
    ConsumablePart part,
    PartSetting Function(PartSetting current) transform,
  ) async {
    final vehicle = ref.read(selectedVehicleProvider);
    if (vehicle == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final next = transform(vehicle.settingFor(part.id));
      final settings = Map<String, PartSetting>.from(vehicle.partSettings);
      if (next.isEmpty) {
        settings.remove(part.id);
      } else {
        settings[part.id] = next;
      }
      await ref
          .read(vehiclesProvider.notifier)
          .upsert(vehicle.copyWith(partSettings: settings));
    });
    return !state.hasError;
  }
}

final partSettingsControllerProvider =
    AsyncNotifierProvider<PartSettingsController, void>(
      PartSettingsController.new,
    );

class MaintenanceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> logService({
    required DateTime date,
    required int odometer,
    required String title,
    required ServiceTier tier,
    List<ConsumablePart> replacedParts = const [],
    List<String> inspectedKeys = const [],
    List<String> customItems = const [],
    double cost = 0,
    String? workshopName,
    String? notes,
    int? milestoneOdometer,
    int? milestonePhase,
    List<String> invoiceAttachments = const [],
  }) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return false;

    return _run(() async {
      var resolvedMilestonePhase = milestonePhase;
      var resolvedMilestoneOdometer = milestoneOdometer;

      // A manual entry opened with no milestone attached — the schedule
      // wasn't tapped, the form was just filled in — still auto-completes
      // the nearest pending or upcoming stop of the same service type, using
      // this entry's own date and odometer as the completion reading. The
      // dynamic schedule then recalculates every later target from it on the
      // next read, with no separate "Mark done" step required.
      if (resolvedMilestonePhase == null) {
        final vehicle = ref.read(selectedVehicleProvider);
        if (vehicle != null) {
          final match = ref
              .read(predictServicesProvider)
              .matchOpenMilestone(
                vehicle: vehicle,
                records: ref.read(completedRecordsProvider),
                tier: tier,
                avgDailyKmFromFuel: ref.read(avgDailyKmProvider),
              );
          if (match != null) {
            resolvedMilestonePhase = match.milestone.phaseIndex;
            resolvedMilestoneOdometer = match.milestone.targetOdometer;
          }
        }
      }

      // Idempotent by phase: logging the same phase twice replaces the
      // existing entry instead of appending a second billable record. Phase
      // is the stable identity — the target odometer offered alongside it is
      // a moving projection and cannot be used to find a prior log.
      final existing = resolvedMilestonePhase == null
          ? null
          : ref
                .read(maintenanceRepositoryProvider)
                .findByPhase(vehicleId, resolvedMilestonePhase);

      await ref
          .read(maintenanceRecordsProvider.notifier)
          .upsert(
            MaintenanceRecord(
              id: existing?.id ?? ref.read(uuidProvider).v4(),
              vehicleId: vehicleId,
              date: date,
              odometer: odometer,
              title: title,
              tier: tier,
              replacedParts: replacedParts,
              inspectedKeys: inspectedKeys,
              customItems: customItems,
              cost: cost,
              workshopName: workshopName,
              notes: notes,
              milestoneOdometer: resolvedMilestoneOdometer,
              milestonePhase: resolvedMilestonePhase,
              // Re-logging the same phase replaces the earlier record, so an
              // entry that attaches nothing would silently drop whatever was
              // already on file.
              invoiceAttachments: invoiceAttachments.isEmpty
                  ? (existing?.invoiceAttachments ?? const [])
                  : invoiceAttachments,
            ),
          );
      await ref
          .read(vehiclesProvider.notifier)
          .updateOdometer(vehicleId, odometer);
    });
  }

  /// Books a service for a date in the future.
  ///
  /// **Nothing about a booking is idempotent by phase, and that is
  /// deliberate.** `logService` replaces an earlier record for the same
  /// milestone because logging one service twice is an edit; booking one is
  /// not — a driver may hold two appointments, and the second is not a
  /// correction of the first. It also never touches the vehicle odometer: the
  /// reading on an appointment is a guess about next month.
  Future<bool> bookService({
    required DateTime scheduledDate,
    required int odometer,
    required String title,
    required ServiceTier tier,
    List<ConsumablePart> replacedParts = const [],
    List<String> inspectedKeys = const [],
    double cost = 0,
    String? workshopName,
    String? notes,
    int? milestoneOdometer,
    int? milestonePhase,
    List<String> invoiceAttachments = const [],
  }) async {
    final vehicleId = ref.read(selectedVehicleIdOrFirstProvider);
    if (vehicleId == null) return false;

    return _run(
      () => ref
          .read(maintenanceRecordsProvider.notifier)
          .upsert(
            MaintenanceRecord(
              id: ref.read(uuidProvider).v4(),
              vehicleId: vehicleId,
              // Mirrored, because everything in the app sorts on `date` and a
              // booking belongs on the day it is booked for.
              date: scheduledDate,
              status: ServiceStatus.scheduled,
              scheduledDate: scheduledDate,
              odometer: odometer,
              title: title,
              tier: tier,
              replacedParts: replacedParts,
              inspectedKeys: inspectedKeys,
              cost: cost,
              workshopName: workshopName,
              notes: notes,
              milestoneOdometer: milestoneOdometer,
              milestonePhase: milestonePhase,
              invoiceAttachments: invoiceAttachments,
            ),
          ),
    );
  }

  /// Confirms a booking as carried out on [on].
  ///
  /// This is the moment the entry becomes history: its parts reset, its
  /// milestone closes, its cost counts, and the two reminders armed for the
  /// appointment stop — the reschedule that follows the write simply does not
  /// re-arm a record that is no longer booked.
  ///
  /// The odometer moves with it, as it does for any completed service, because
  /// by now the reading is a fact rather than a projection.
  Future<bool> markCompleted(MaintenanceRecord record, {DateTime? on}) async {
    if (record.isCompleted) return true;

    return _run(() async {
      final done = record.completedOn(on ?? DateTime.now());
      await ref.read(maintenanceRecordsProvider.notifier).upsert(done);
      await ref
          .read(vehiclesProvider.notifier)
          .updateOdometer(done.vehicleId, done.odometer);
    });
  }

  Future<bool> save(MaintenanceRecord record) =>
      _run(() => ref.read(maintenanceRecordsProvider.notifier).upsert(record));

  Future<bool> remove(String id) =>
      _run(() => ref.read(maintenanceRecordsProvider.notifier).remove(id));

  Future<bool> resetPart(ConsumablePart part, {int? odometer}) async {
    final vehicle = ref.read(selectedVehicleProvider);
    if (vehicle == null) return false;

    return _run(
      () => ref
          .read(partReplacementsProvider.notifier)
          .resetPart(
            vehicleId: vehicle.id,
            part: part,
            odometer: odometer ?? vehicle.currentOdometer,
          ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final maintenanceControllerProvider =
    AsyncNotifierProvider<MaintenanceController, void>(
      MaintenanceController.new,
    );
