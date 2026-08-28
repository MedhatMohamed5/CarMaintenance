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
/// | Service & parts, by distance | within 1,000 km, date still further out | every 2 days |
///
/// **The date rule outranks the distance rule, and the order matters.** Both
/// can be true at once — a car 700 km from its target is usually also days away
/// from it — and whichever branch is tested first decides the cadence. Testing
/// distance first, as this did originally, meant an item three days out got the
/// every-other-day rhythm instead of the daily one: the app nagged *less* as
/// the deadline got closer. Distance is what catches the driver who covers a
/// year's kilometres in a month, so it belongs in the branch that runs while
/// the projected date is still far off.
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
  ///
  /// The same threshold the dashboard card and the status badges use, so a
  /// notification never arrives about something the app is not yet showing.
  static const int distanceThresholdKm = ServiceThresholds.dueSoonKm;

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

  /// Urgency bands, so a plan's rank under the budget reflects the rule that
  /// produced it rather than raw units that are not comparable. Lower is more
  /// pressing: an open date window (0-14) beats a distance trigger (100-200),
  /// which beats a date window that has not opened yet (1000+).
  static const int _urgencyDistanceBase = 100;

  static const int _urgencyFutureDateBase = 1000;

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

      // The target is recalculated from the driver's own completed-service
      // history, so both branches below measure against where this phase
      // actually falls due rather than a fixed multiple of the interval.
      final estimated = service.estimatedDate;
      final dateWindowOpen = _isDateWindowOpen(estimated);

      // Distance only while the date is further out than the lead time, or
      // cannot be projected at all.
      if (!dateWindowOpen && _isWithinDistance(service.kmRemaining)) {
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
            urgency: _distanceUrgency(service.kmRemaining),
          ),
        );
        continue;
      }

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
          urgency: _dateUrgency(estimated, start, open: dateWindowOpen),
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
      final due = health.estimatedDueDate;
      final dateWindowOpen =
          health.status != HealthStatus.healthy && _isDateWindowOpen(due);

      if (!dateWindowOpen && _isWithinDistance(remaining)) {
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
            urgency: _distanceUrgency(remaining),
          ),
        );
        continue;
      }

      // Outside the distance window, only nag about parts actually approaching
      // their limit.
      if (health.status == HealthStatus.healthy || due == null) continue;
      final start = due.subtract(const Duration(days: serviceLeadDays));

      plans.add(
        _ReminderPlan(
          key: '$key-date',
          title: l10n.raw('notifPartTitle'),
          body: l10n.fmt('alertPartDueSoon', {'part': label}),
          from: start,
          everyDays: 1,
          occurrences: dailyOccurrences,
          urgency: _dateUrgency(due, start, open: dateWindowOpen),
        ),
      );
    }

    return plans;
  }

  // ---- scheduling primitives ---------------------------------------------

  /// Arms a plan's run of reminders, up to [limit] of them, and reports how
  /// many were actually scheduled.
  ///
  /// The run is **anchored forward**, never replayed from its start. A window
  /// that opened in the past resumes at the next slot and still gets its full
  /// count, which is the whole reason an overdue item keeps nagging.
  ///
  /// It used to skip past occurrences instead of shifting them, and that was a
  /// silent failure at exactly the wrong moment: a date-driven plan starts
  /// [serviceLeadDays] *before* the projected date and runs for
  /// [dailyOccurrences] days, so its last slot is 9 am on the due date itself.
  /// From that morning on, every occurrence was in the past and the item armed
  /// **nothing** — the app went quiet precisely when the service came due.
  ///
  /// Each occurrence carries its index in the id, which keeps the run
  /// replaceable on the next reschedule.
  Future<int> _arm(
    ReminderNotifier notifier,
    _ReminderPlan plan, {
    required int limit,
  }) async {
    final start = _firstSlotFrom(plan.from);
    var armed = 0;

    for (var i = 0; i < plan.occurrences && armed < limit; i++) {
      await notifier.schedule(
        id: reminderIdFor('${plan.key}-$i'),
        title: plan.title,
        body: plan.body,
        when: start.add(Duration(days: plan.everyDays * i)),
        payload: plan.key,
      );
      armed++;
    }

    return armed;
  }

  /// The first 9 am slot at or after [from] that has not already passed.
  ///
  /// Two separate cases collapse into one rule here: a window whose start is
  /// still ahead keeps it, and a window already open — or long overdue — starts
  /// at the next morning instead. The extra day-hop matters because a
  /// reschedule triggered at, say, 5 pm would otherwise burn its first slot on
  /// a 9 am that is eight hours gone.
  static DateTime _firstSlotFrom(DateTime from) {
    final now = DateTime.now();
    final slot = _at9am(from.isAfter(now) ? from : now);
    return slot.isAfter(now) ? slot : slot.add(const Duration(days: 1));
  }

  /// Whole days from now until [date], floored at zero.
  static int _daysFromNow(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  /// Whether the daily window has opened: the projected date is inside the
  /// lead time, or already behind us. Null means there is not yet enough
  /// history to project a date, which is exactly when distance has to carry the
  /// reminder on its own.
  static bool _isDateWindowOpen(DateTime? projected) =>
      projected != null && _daysFromNow(projected) <= serviceLeadDays;

  /// Whether the target is close enough to switch to distance-driven
  /// reminders. Already-passed targets count: overdue is as close as it gets.
  static bool _isWithinDistance(int kmRemaining) =>
      kmRemaining <= distanceThresholdKm;

  /// Ranks a distance plan within its band, in 10 km steps so the whole
  /// threshold fits the band without spilling into the next one.
  static int _distanceUrgency(int kmRemaining) =>
      _urgencyDistanceBase + _atLeastZero(kmRemaining) ~/ 10;

  /// An open window ranks by days left, ahead of every other kind of plan. One
  /// still to come ranks behind them all, by how long until it opens.
  static int _dateUrgency(
    DateTime projected,
    DateTime start, {
    required bool open,
  }) => open
      ? _daysFromNow(projected)
      : _urgencyFutureDateBase + _daysFromNow(start);

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
