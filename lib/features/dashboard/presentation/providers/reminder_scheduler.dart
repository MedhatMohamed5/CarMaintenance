import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/service_thresholds.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/reminder_notifier.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/domain/entities/routine_check.dart';
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
/// Five schedules, five rhythms:
///
/// | Category | Trigger | Repeat |
/// |---|---|---|
/// | Documents | 30 / 7 / 1 days before expiry | once each |
/// | Booked services | the day before, and the morning of | once each |
/// | Routine checks | a standing cadence, never data-driven | 14 / 30 days |
/// | Service & parts, **overdue** | either limit already passed | daily |
/// | Service & parts, by date | from 14 days before the projected date | daily |
/// | Service & parts, by distance | within 1,000 km, date still further out | every 2 days |
///
/// **Overdue is tested before either window, and says so.** Distance and time
/// are two limits on one deadline, and passing *either* is overdue — a car
/// 400 km from its target that is already two months past the calendar limit
/// for that service is late, not approaching. Both branches below used to
/// describe every item as coming up, so the app told a driver their service was
/// "coming up" for as long as they left it undone. That is not a wording
/// problem: a reminder that never escalates is one the driver learns to ignore.
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

  /// An overdue item nags daily for as long as the horizon reaches. Same
  /// cadence as an open date window, because by then they are the same thing.
  static const int overdueOccurrences = dailyOccurrences;

  /// How far ahead each routine check is armed. Three checks over four
  /// occurrences each is twelve reminders, which is what [routineReserve] is
  /// sized for.
  static const int routineOccurrences = 4;

  /// Urgency bands, so a plan's rank under the budget reflects the rule that
  /// produced it rather than raw units that are not comparable. Lower is more
  /// pressing: an open date window (0-14) beats a distance trigger (100-200),
  /// which beats a date window that has not opened yet (1000+).
  static const int _urgencyDistanceBase = 100;

  static const int _urgencyFutureDateBase = 1000;

  /// Overdue outranks every other kind of plan, and further past outranks
  /// nearer past. Negative so it can never collide with the bands above, no
  /// matter how large a distance or day count arrives.
  static const int _urgencyOverdueBase = -1000;

  /// Days past the deadline beyond which an item cannot get any more urgent.
  static const int _overdueUrgencyCeiling = 900;

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

  /// Hours of day the two booking reminders land on.
  ///
  /// The day-before one is a mid-morning heads-up; the day-of one is earlier,
  /// because a workshop appointment is usually a morning appointment and a
  /// reminder that arrives after the driver has already left for work is a
  /// reminder that arrived too late to be acted on.
  static const int bookingEveHour = 9;

  static const int bookingDayHour = 8;

  /// Reserved, not ranked. A booking is an appointment the driver made with a
  /// third party — the one deadline in this app that costs them something to
  /// miss even when the car is perfectly healthy — so it must not lose a
  /// budget comparison to a wear projection. Two slots each covers four live
  /// bookings, well past what anyone holds at once.
  static const int bookingReserve = 8;

  /// Routine checks are reserved out of the budget rather than ranked into it.
  /// They carry no deadline, so they lose every comparison against a real one
  /// and would be squeezed out entirely on a car with a full service list —
  /// which is precisely the car whose coolant is worth looking at.
  static const int routineReserve = 12;

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
    final bookingUsed = await _scheduleBookings(notifier, l10n);
    final routineUsed = await _scheduleRoutineChecks(notifier, l10n);

    // Everything else competes for one budget, spent most-urgent first: an
    // overdue item outranks one 200 km from its target, which outranks one
    // whose projected date is a fortnight out, and a dropped reminder is always
    // the least pressing one.
    final plans = [..._servicePlans(l10n, locale), ..._partPlans(l10n, locale)]
      ..sort((a, b) => a.urgency.compareTo(b.urgency));

    var remaining = pendingBudget - documentReserve - bookingUsed - routineUsed;
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

  // ---- booked services ---------------------------------------------------

  /// Arms the two reminders for every open booking, and reports the slots used.
  ///
  /// **Armed here rather than cancelled and re-armed as bookings change.**
  /// [rescheduleAll] cancels everything before it starts, so a booking that was
  /// deleted, moved or confirmed as done is simply absent from the list below
  /// and never re-arms — which is the whole of "notifications must be cancelled
  /// or updated when the booking is". There is no separate cancel path to keep
  /// in step, and therefore no way for one to fall out of step.
  ///
  /// Instants in the past are dropped by the notifier itself, so booking today
  /// for tomorrow arms one reminder rather than failing on the one whose
  /// morning has already gone.
  Future<int> _scheduleBookings(
    ReminderNotifier notifier,
    AppLocalizations l10n,
  ) async {
    var used = 0;
    final now = DateTime.now();

    for (final booking in _ref.read(scheduledRecordsProvider)) {
      if (used >= bookingReserve) break;
      final when = booking.scheduledDate;
      // Defensive: `bookService` always sets it, but a record edited by hand
      // into the scheduled state might not have. Skip it rather than stopping
      // the pass and starving every booking behind it.
      if (when == null) continue;

      final body = _bookingBody(booking, l10n);
      final slots = <({String suffix, DateTime at, String title})>[
        (
          suffix: 'eve',
          at: _atHour(when.subtract(const Duration(days: 1)), bookingEveHour),
          title: l10n.raw('notifBookingTomorrowTitle'),
        ),
        (
          suffix: 'day',
          at: _atHour(when, bookingDayHour),
          title: l10n.raw('notifBookingTodayTitle'),
        ),
      ];

      for (final slot in slots) {
        if (!slot.at.isAfter(now)) continue;
        await notifier.schedule(
          id: reminderIdFor('booking-${booking.id}-${slot.suffix}'),
          title: slot.title,
          body: body,
          when: slot.at,
          payload: 'booking-${booking.id}',
        );
        used++;
      }
    }
    return used;
  }

  /// What the service is, and where — the two things the driver needs at a
  /// glance to know whether this is the appointment they are thinking of.
  static String _bookingBody(MaintenanceRecord booking, AppLocalizations l10n) {
    final workshop = booking.workshopName?.trim() ?? '';
    final title = booking.title.trim().isEmpty
        ? l10n.raw(booking.tier.l10nKey)
        : booking.title.trim();
    return workshop.isEmpty ? title : '$title — $workshop';
  }

  // ---- routine checks ----------------------------------------------------

  /// Arms the standing checks and reports how many slots they took.
  ///
  /// Runs before the competitive pass and outside it — see [routineReserve].
  /// Returns zero, and arms nothing, when the driver has turned them off.
  Future<int> _scheduleRoutineChecks(
    ReminderNotifier notifier,
    AppLocalizations l10n,
  ) async {
    if (!_ref.read(routineChecksEnabledProvider)) return 0;

    var used = 0;
    for (final check in RoutineCheck.values) {
      if (used >= routineReserve) break;
      used += await _arm(
        notifier,
        _ReminderPlan(
          key: check.reminderKey,
          title: l10n.raw(check.titleKey),
          body: l10n.raw(check.bodyKey),
          // Staggered per check, so the three never share a morning.
          from: DateTime.now().add(Duration(days: check.offsetDays)),
          everyDays: check.everyDays,
          occurrences: routineOccurrences,
          // Never ranked — reserved. Held at the far end of the scale anyway so
          // a future change that does rank them cannot outrank a deadline.
          urgency: _urgencyFutureDateBase * 2,
        ),
        limit: routineReserve - used,
      );
    }
    return used;
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

      // Both limits, tested together and before either window. `isOverdue` is
      // true the moment the target odometer is passed *or* the projected date
      // is, so neither constraint can be masked by the other still being
      // comfortable.
      if (service.isOverdue) {
        plans.add(
          _ReminderPlan(
            key: '$key-overdue',
            title: l10n.raw('notifServiceOverdueTitle'),
            body: l10n.fmt('alertServiceOverdue', {
              'km': Fmt.int0(service.milestone.targetOdometer, locale),
            }),
            from: DateTime.now(),
            everyDays: 1,
            occurrences: overdueOccurrences,
            urgency: _overdueUrgency(_daysPast(estimated)),
          ),
        );
        continue;
      }

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

      final due = health.estimatedDueDate;

      // Same rule as a service, and it reaches here through
      // `rawWearFraction`: `CalculatePartsHealth` takes whichever of the
      // distance and calendar budgets is further along, so a part still inside
      // its distance interval but past its months limit already reads as fully
      // worn.
      if (health.isOverdue) {
        plans.add(
          _ReminderPlan(
            key: '$key-overdue',
            title: l10n.raw('notifPartOverdueTitle'),
            body: l10n.fmt('alertPartOverdue', {'part': label}),
            from: DateTime.now(),
            everyDays: 1,
            occurrences: overdueOccurrences,
            urgency: _overdueUrgency(_daysPast(due)),
          ),
        );
        continue;
      }

      // `remainingKm` is derived from the vehicle's live odometer, so this
      // re-evaluates on every odometer update and every fuel or service log
      // that moves it.
      final remaining = health.remainingKm;
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

  /// How long an item has been past its projected date, in whole days.
  ///
  /// Zero when the odometer target has been passed but the projected date is
  /// still ahead: there is no calendar figure to measure against, and "just
  /// overdue" is the honest floor.
  static int _daysPast(DateTime? projected) {
    if (projected == null) return 0;
    final days = DateTime.now().difference(projected).inDays;
    return days < 0 ? 0 : days;
  }

  /// Ranks an overdue plan: further past the deadline is more urgent, down to a
  /// floor so the band cannot run away from itself.
  static int _overdueUrgency(int daysPast) =>
      _urgencyOverdueBase +
      (daysPast >= _overdueUrgencyCeiling
          ? 0
          : _overdueUrgencyCeiling - daysPast);

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
  static DateTime _at9am(DateTime d) => _atHour(d, 9);

  /// The given day at [hour] local, with whatever time of day [d] carried
  /// discarded — a reminder is pinned to a time we chose, not to the minute a
  /// record happened to be saved at.
  static DateTime _atHour(DateTime d, int hour) {
    final day = DateX.dayOnly(d);
    return DateTime(day.year, day.month, day.day, hour);
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
  final bookings = ref.watch(scheduledRecordsProvider);
  final enabled = ref.watch(notificationsEnabledProvider);
  final routine = ref.watch(routineChecksEnabledProvider);

  return Object.hash(
    vehicle?.id,
    vehicle?.currentOdometer,
    vehicle?.licenseExpiry,
    vehicle?.insuranceExpiry,
    services.length,
    Object.hashAll(services.map(_serviceFingerprint)),
    parts.length,
    Object.hashAll(parts.map(_partFingerprint)),
    bookings.length,
    Object.hashAll(bookings.map(_bookingFingerprint)),
    enabled,
    routine,
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

/// Exactly what the two reminders are built from. Booking, moving or
/// confirming an appointment changes this; editing its cost does not, because
/// nothing armed depends on that.
int _bookingFingerprint(MaintenanceRecord booking) => Object.hash(
  booking.id,
  booking.scheduledDate,
  booking.title,
  booking.workshopName,
);

int _partFingerprint(PartHealth health) => Object.hash(
  health.part,
  health.status,
  _distanceBucket(health.isOverdue ? 0 : health.remainingKm),
);
