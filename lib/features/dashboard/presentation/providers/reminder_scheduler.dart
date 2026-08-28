import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/service_thresholds.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/reminder_notifier.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/domain/entities/upcoming_service.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';

/// Fires local notifications ahead of every deadline the app knows about.
///
/// Runs as a listener rather than on a timer: whenever the underlying data
/// changes — a fill is logged, a part is reset, the odometer is updated — the
/// whole reminder set is recomputed and re-scheduled. Notification ids are
/// derived from a stable domain key plus the occurrence index, so rescheduling
/// replaces rather than duplicates.
///
/// Three schedules, three rhythms:
///
/// | Category | Trigger | Repeat |
/// |---|---|---|
/// | Documents | 30 / 7 / 1 days before expiry | once each |
/// | Service & parts, by date | from 14 days before the projected date | daily |
/// | Service & parts, by distance | within 1,000 km of the target | every 2 days |
///
/// A repeating reminder stops the moment the item is completed, because
/// completion removes it from `upcomingServicesProvider` or drops the part back
/// to healthy, and the next reschedule simply does not re-arm it.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  /// Document reminder lead times, in days before expiry. Unchanged.
  static const List<int> documentLeadDays = [30, 7, 1];

  /// Daily reminders start this far ahead of the projected date, matching the
  /// in-app due-soon threshold.
  static const int serviceLeadDays = ServiceThresholds.dueSoonDays;

  /// Distance at which the reminder switches from "coming up" to "now".
  static const int distanceThresholdKm = 1000;

  /// Cadence of the distance-triggered reminder, in days.
  static const int distanceRepeatDays = 2;

  /// How far ahead a repeating reminder is armed.
  ///
  /// `flutter_local_notifications` schedules discrete instants, so a "daily
  /// until done" reminder is a run of individual notifications. The horizon
  /// bounds that run: long enough to cover the whole window, short enough that
  /// the OS pending-notification limit is never approached. Every reschedule
  /// re-arms from today, so the run never runs out while the app is in use.
  static const int dailyOccurrences = serviceLeadDays + 1;

  static const int distanceOccurrences = 7;

  /// Hard ceiling on pending notifications.
  ///
  /// iOS keeps at most 64 pending local notifications per app and silently
  /// drops everything past that, with no guarantee about *which* survive. A
  /// naive "daily until done" across three services and seventeen wear parts
  /// arms over three hundred, so the run has to be budgeted rather than
  /// emitted. Documents are reserved out of the budget because they are the
  /// one category with a legal deadline behind it.
  static const int pendingBudget = 60;

  static const int documentReserve = 6;

  Timer? _debounce;

  /// Coalesces the burst of provider updates that follows a single user action
  /// into one scheduling pass.
  void scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), rescheduleAll);
  }

  Future<void> rescheduleAll() async {
    if (!_ref.read(notificationsEnabledProvider)) return;

    final vehicle = _ref.read(selectedVehicleProvider);
    final notifier = _ref.read(notificationServiceProvider);
    final l10n = _ref.read(l10nProvider);
    final locale = _ref.read(localeTagProvider);

    // Cancelling first is what makes a completed item stop nagging: it is
    // dropped from the source lists, so nothing re-arms it below.
    await notifier.cancelAll();
    if (vehicle == null) return;

    await _scheduleDocuments(vehicle, notifier, l10n, locale);

    // Everything else competes for one budget, spent most-urgent first: an
    // item 200 km from its target outranks one whose projected date is a
    // fortnight out, and a dropped reminder is always the least pressing one.
    final plans = [..._servicePlans(l10n, locale), ..._partPlans(l10n, locale)]
      ..sort((a, b) => a.urgency.compareTo(b.urgency));

    var remaining = pendingBudget - documentReserve;
    for (final plan in plans) {
      if (remaining <= 0) break;
      remaining -= await _arm(notifier, plan, limit: remaining);
    }
  }

  // ---- documents: unchanged, one shot per lead time ----------------------

  Future<void> _scheduleDocuments(
    Vehicle vehicle,
    ReminderNotifier notifier,
    AppLocalizations l10n,
    String locale,
  ) async {
    Future<void> forDocument(DateTime? expiry, String key, String label) async {
      if (expiry == null) return;
      for (final lead in documentLeadDays) {
        await notifier.schedule(
          id: reminderIdFor('$key-$lead'),
          title: l10n.raw('notifDocumentTitle'),
          body: '$label — ${l10n.fmt('remainingDays', {'n': lead})}',
          when: _at9am(expiry.subtract(Duration(days: lead))),
          payload: key,
        );
      }
    }

    await forDocument(
      vehicle.licenseExpiry,
      'doc-license-${vehicle.id}',
      l10n.carLicense,
    );
    await forDocument(
      vehicle.insuranceExpiry,
      'doc-insurance-${vehicle.id}',
      l10n.carInsurance,
    );
  }

  // ---- services ----------------------------------------------------------

  List<_ReminderPlan> _servicePlans(AppLocalizations l10n, String locale) {
    final plans = <_ReminderPlan>[];

    for (final service in _ref.read(upcomingServicesProvider)) {
      if (service.isCompleted) continue;
      // Keyed by the stable phase id, not the dynamically projected target
      // odometer, so the reminder run survives the target drifting when an
      // earlier phase closes off-grid.
      final key = 'service-${service.milestone.id}';

      // Distance wins when the car is within the threshold — evaluated
      // against the dynamically recalculated target for this phase, which
      // already reflects the driver's own completed-service history.
      if (_isWithinDistance(service.kmRemaining)) {
        plans.add(
          _ReminderPlan(
            key: '$key-km',
            title: l10n.raw('notifServiceKmTitle'),
            body: l10n.fmt('alertServiceKmRemaining', {
              'km': Fmt.int0(service.milestone.targetOdometer, locale),
              'remaining': Fmt.int0(_atLeastZero(service.kmRemaining), locale),
            }),
            from: DateTime.now(),
            everyDays: distanceRepeatDays,
            occurrences: distanceOccurrences,
            urgency: _atLeastZero(service.kmRemaining),
          ),
        );
        continue;
      }

      final estimated = service.estimatedDate;
      if (estimated == null) continue;
      final start = estimated.subtract(const Duration(days: serviceLeadDays));

      plans.add(
        _ReminderPlan(
          key: '$key-date',
          title: l10n.raw('notifServiceTitle'),
          body: l10n.fmt('alertServiceDueSoon', {
            'km': service.milestone.targetOdometer,
          }),
          from: start,
          everyDays: 1,
          occurrences: dailyOccurrences,
          // Date-driven plans rank behind every distance-driven one, then
          // among themselves by how soon the window opens.
          urgency: distanceThresholdKm + _daysFromNow(start),
        ),
      );
    }

    return plans;
  }

  // ---- wear parts --------------------------------------------------------

  List<_ReminderPlan> _partPlans(AppLocalizations l10n, String locale) {
    final plans = <_ReminderPlan>[];

    for (final health in _ref.read(allPartsHealthProvider)) {
      final key = 'part-${health.part.id}';
      final label = l10n.raw(health.part.l10nKey);

      // `remainingKm` is derived from the vehicle's live odometer, so this
      // re-evaluates on every odometer update and every fuel or service log
      // that moves it.
      final remaining = health.isOverdue ? 0 : health.remainingKm;
      if (_isWithinDistance(remaining)) {
        plans.add(
          _ReminderPlan(
            key: '$key-km',
            title: l10n.raw('notifPartTitle'),
            body: l10n.fmt('alertPartKmRemaining', {
              'part': label,
              'remaining': Fmt.int0(remaining, locale),
            }),
            from: DateTime.now(),
            everyDays: distanceRepeatDays,
            occurrences: distanceOccurrences,
            urgency: remaining,
          ),
        );
        continue;
      }

      // Outside the distance window, only nag about parts actually approaching
      // their limit.
      if (health.status == HealthStatus.healthy) continue;
      final due = health.estimatedDueDate;
      if (due == null) continue;
      final start = due.subtract(const Duration(days: serviceLeadDays));

      plans.add(
        _ReminderPlan(
          key: '$key-date',
          title: l10n.raw('notifPartTitle'),
          body: l10n.fmt('alertPartDueSoon', {'part': label}),
          from: start,
          everyDays: 1,
          occurrences: dailyOccurrences,
          urgency: distanceThresholdKm + _daysFromNow(start),
        ),
      );
    }

    return plans;
  }

  // ---- scheduling primitives ---------------------------------------------

  /// Arms a plan's run of reminders, up to [limit] of them, and reports how
  /// many were actually scheduled.
  ///
  /// Occurrences already in the past are skipped rather than shifted, so a
  /// window the user is halfway through resumes at today rather than replaying
  /// from its start. Each occurrence carries its index in the id, which keeps
  /// the run replaceable on the next reschedule.
  Future<int> _arm(
    ReminderNotifier notifier,
    _ReminderPlan plan, {
    required int limit,
  }) async {
    final now = DateTime.now();
    var armed = 0;

    for (var i = 0; i < plan.occurrences && armed < limit; i++) {
      final when = _at9am(plan.from.add(Duration(days: plan.everyDays * i)));
      if (!when.isAfter(now)) continue;
      await notifier.schedule(
        id: reminderIdFor('${plan.key}-$i'),
        title: plan.title,
        body: plan.body,
        when: when,
        payload: plan.key,
      );
      armed++;
    }

    return armed;
  }

  /// Whole days from now until [date], floored at zero.
  static int _daysFromNow(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  /// Whether the target is close enough to switch to distance-driven
  /// reminders. Already-passed targets count: overdue is as close as it gets.
  static bool _isWithinDistance(int kmRemaining) =>
      kmRemaining <= distanceThresholdKm;

  static int _atLeastZero(int value) => value < 0 ? 0 : value;

  /// Reminders land mid-morning: late enough not to wake anyone, early enough
  /// to act on the same day.
  static DateTime _at9am(DateTime d) {
    final day = DateX.dayOnly(d);
    return DateTime(day.year, day.month, day.day, 9);
  }

  void dispose() => _debounce?.cancel();
}

/// One item's reminder run, resolved but not yet armed.
///
/// Held as data so the whole set can be ranked against a shared budget before
/// anything is handed to the OS.
class _ReminderPlan {
  const _ReminderPlan({
    required this.key,
    required this.title,
    required this.body,
    required this.from,
    required this.everyDays,
    required this.occurrences,
    required this.urgency,
  });

  final String key;
  final String title;
  final String body;
  final DateTime from;
  final int everyDays;
  final int occurrences;

  /// Lower is more pressing. Distance plans use the kilometres remaining;
  /// date plans start above [ReminderScheduler.distanceThresholdKm] so they
  /// always rank behind a measured distance.
  final int urgency;
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Fingerprint of everything a reminder depends on. Pure by design — the
/// previous version called `scheduleSoon()` inside its own `build`, which is a
/// side effect during build and can re-enter the provider graph. Consumers
/// `ref.listen` to this and trigger scheduling from the listener instead.
///
/// The per-item remaining distances are part of the hash on purpose: that is
/// what makes a new odometer reading — from the odometer sheet, a fuel log or a
/// service log — re-arm the distance-triggered reminders immediately.
final reminderSignatureProvider = Provider<int>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  final services = ref.watch(upcomingServicesProvider);
  final parts = ref.watch(allPartsHealthProvider);
  final enabled = ref.watch(notificationsEnabledProvider);

  return Object.hash(
    vehicle?.id,
    vehicle?.currentOdometer,
    vehicle?.licenseExpiry,
    vehicle?.insuranceExpiry,
    services.length,
    Object.hashAll(services.map(_serviceFingerprint)),
    parts.length,
    Object.hashAll(parts.map(_partFingerprint)),
    enabled,
  );
});

/// Buckets the remaining distance so the hash changes when an item crosses the
/// threshold, or moves a meaningful step within it, rather than on every single
/// kilometre.
int _distanceBucket(int kmRemaining) {
  if (kmRemaining > ReminderScheduler.distanceThresholdKm) {
    return ReminderScheduler.distanceThresholdKm + 1;
  }
  return (kmRemaining < 0 ? 0 : kmRemaining) ~/ 100;
}

int _serviceFingerprint(UpcomingService service) => Object.hash(
  service.milestone.targetOdometer,
  service.isCompleted,
  _distanceBucket(service.kmRemaining),
);

int _partFingerprint(PartHealth health) => Object.hash(
  health.part,
  health.status,
  _distanceBucket(health.isOverdue ? 0 : health.remainingKm),
);
