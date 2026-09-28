import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/service_thresholds.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/reminder_notifier.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../fuel/domain/entities/fuel_stats.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../maintenance/domain/entities/maintenance_record.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/domain/entities/routine_check.dart';
import '../../../maintenance/domain/entities/seasonal_check.dart';
import '../../../maintenance/domain/entities/upcoming_service.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../maintenance/presentation/providers/price_providers.dart';
import '../../../parking/presentation/providers/parking_providers.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/reminder_category.dart';
import 'reminder_prefs.dart';

/// Fires local notifications ahead of every deadline the app knows about, and
/// the handful of nudges worth sending without one.
///
/// Runs as a listener rather than on a timer: whenever the underlying data
/// changes — a fill is logged, a part is reset, the odometer is updated — and
/// whenever the app returns to the foreground, the whole set is recomputed and
/// re-armed. Notification ids come from stable keys, so re-arming replaces
/// rather than duplicates.
///
/// | Kind | Trigger | Repeat |
/// |---|---|---|
/// | Documents | 30 / 7 / 1 days before expiry | once each |
/// | Bookings | the day before, the morning of, the day after if unconfirmed | once each |
/// | Service & parts, **overdue** | either limit already passed | daily |
/// | Service & parts, by date | from 14 days before the projected date | daily |
/// | Service & parts, by distance | within 1,000 km, date still further out | every 2 days |
/// | Routine checks | a fixed cadence from a stored start day | 14 / 30 days |
/// | Seasonal checks | ahead of khamaseen, summer and winter | yearly |
/// | Odometer | 14 days after the last reading | weekly |
/// | Fuel consumption | the last 3 fills 15% worse than the rest | once per rise |
/// | Monthly summary | the 1st, about the month before | monthly |
/// | Parking | the minute the driver asked for | once |
///
/// **Everything is planned first and armed second.** Each kind contributes
/// candidates; [_select] then drops the kinds the driver switched off, holds
/// the advisory ones to [dailyCap] a day — pushing the ones that can wait a day
/// or two rather than losing them — and fits the result under
/// [pendingBudget]. Arming as each kind was computed, as this used to, could
/// not do either: nothing saw the whole day, so nothing could say it was full.
///
/// **Overdue is tested before either window, and says so.** Distance and time
/// are two limits on one deadline, and passing *either* is overdue — a car
/// 400 km from its target that is already two months past the calendar limit
/// for that service is late, not approaching. A reminder that never escalates
/// is one the driver learns to ignore.
///
/// **The date rule outranks the distance rule, and the order matters.** Both
/// can be true at once, and whichever branch is tested first decides the
/// cadence. Testing distance first meant an item three days out got the
/// every-other-day rhythm instead of the daily one: the app nagged *less* as
/// the deadline got closer.
///
/// A repeating reminder stops the moment the item is completed, because
/// completion removes it from its source list and the next pass simply does not
/// re-arm it.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  /// Document reminder lead times, in days before expiry.
  static const List<int> documentLeadDays = [30, 7, 1];

  /// Daily reminders start this far ahead of the projected date, matching the
  /// in-app due-soon threshold.
  static const int serviceLeadDays = ServiceThresholds.dueSoonDays;

  /// Distance at which the reminder switches from "coming up" to "now". The
  /// same threshold the dashboard uses, so a notification never arrives about
  /// something the app is not yet showing.
  static const int distanceThresholdKm = ServiceThresholds.dueSoonKm;

  /// Cadence of the distance-triggered reminder, in days.
  static const int distanceRepeatDays = 2;

  /// How far ahead a repeating reminder is armed. `flutter_local_notifications`
  /// schedules discrete instants, so "daily until done" is a run of individual
  /// notifications, re-armed from the next slot on every pass.
  static const int dailyOccurrences = serviceLeadDays + 1;

  static const int distanceOccurrences = 7;

  /// An overdue item nags daily for as long as the horizon reaches.
  static const int overdueOccurrences = dailyOccurrences;

  /// How many future slots each routine check is armed for.
  static const int routineOccurrences = 4;

  /// Days after the last odometer reading before the first nudge, and the
  /// cadence after it.
  static const int odometerStaleDays = 14;
  static const int odometerRepeatDays = 7;
  static const int odometerOccurrences = 2;

  /// Fills compared by the consumption alert: the newest [fuelRecentFills]
  /// against everything before them, of which there must be at least as many.
  /// Three is the fewest that says "trend" rather than "one bad tank".
  static const int fuelRecentFills = 3;

  /// How much worse the recent fills must be before it is worth saying.
  /// Driving pattern alone — a week of traffic, a trip to the coast — moves
  /// consumption by a few percent; fifteen is past that noise.
  static const double fuelRiseThreshold = 0.15;

  /// Advisory reminders allowed on one day. Critical ones — documents,
  /// bookings, parking — do not count and are never held back.
  static const int dailyCap = 2;

  /// How many days an advisory reminder that can wait may be pushed to find a
  /// day with room, before it is dropped.
  static const int maxShiftDays = 3;

  /// Hard ceiling on pending notifications.
  ///
  /// iOS keeps at most 64 pending local notifications per app and silently
  /// drops everything past that, with no guarantee about *which* survive.
  /// Critical reminders are armed first; the rest fill what remains, soonest
  /// first — anything further out is re-armed on a later pass anyway.
  static const int pendingBudget = 60;

  /// Hours of day the two booking reminders land on, whatever the driver's
  /// chosen reminder hour: a workshop appointment is usually a morning one,
  /// and a reminder after the driver has left for work arrives too late.
  static const int bookingEveHour = 9;

  static const int bookingDayHour = 8;

  /// Priority bands for advisory reminders — lower is more pressing — so a
  /// full day keeps what matters. Services and parts rank inside their own
  /// band by how close they are.
  static const int _urgencyOverdueBase = -1000;
  static const int _overdueUrgencyCeiling = 900;
  static const int _priorityBookingFollowUp = 20;
  static const int _priorityOdometer = 30;
  static const int _urgencyDistanceBase = 100;
  static const int _priorityFuelEconomy = 300;
  static const int _urgencyFutureDateBase = 1000;
  static const int _priorityRoutine = 2000;
  static const int _prioritySeasonal = 2100;
  static const int _priorityMonthlySummary = 2200;

  Timer? _debounce;

  /// The driver's reminder hour for the pass in progress.
  int _hour = 9;

  /// The settings screen's scheduled self-test, while it is still ahead.
  ///
  /// Held here because every pass starts by cancelling everything: a
  /// notification this class does not know about is cancelled by the next
  /// pass, and passes now run on every return to the app. The self-test is
  /// exactly the notification a driver goes back into the app to wait for —
  /// cancelling it would make working scheduling look broken, which is the one
  /// thing the test exists to rule out.
  ({String title, String body, DateTime when})? _selfTest;

  static const String _selfTestKey = 'selftest-later';

  Future<void> armSelfTest({
    required String title,
    required String body,
    required DateTime when,
  }) async {
    _selfTest = (title: title, body: body, when: when);
    await _armSelfTest(_ref.read(notificationServiceProvider));
  }

  Future<void> _armSelfTest(ReminderNotifier notifier) async {
    final test = _selfTest;
    if (test == null || !test.when.isAfter(DateTime.now())) return;
    await notifier.schedule(
      id: reminderIdFor(_selfTestKey),
      title: test.title,
      body: test.body,
      when: test.when,
    );
  }

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
    final prefs = _ref.read(reminderPrefsProvider);
    _hour = prefs.hour;

    // Cancelling first is what makes a completed item stop nagging: it is
    // dropped from the source lists, so nothing re-arms it below.
    await notifier.cancelAll();
    await _armSelfTest(notifier);
    if (vehicle == null) return;

    final candidates = <_Candidate>[
      ..._documents(vehicle, l10n),
      ..._bookings(l10n),
      for (final plan in [
        ..._servicePlans(l10n, locale),
        ..._partPlans(l10n, locale),
      ])
        ..._expand(plan),
      ...await _routineChecks(l10n),
      ..._seasonalChecks(l10n),
      ...await _odometerNudges(vehicle, l10n),
      ..._fuelEconomy(l10n),
      ..._monthlySummaries(l10n, locale),
      ..._parking(l10n),
    ].where((c) => prefs.allows(c.category));

    for (final c in _select(candidates)) {
      await notifier.schedule(
        id: reminderIdFor(c.key),
        title: c.title,
        body: c.body,
        when: c.when,
        payload: c.payload,
      );
    }
  }

  // ---- selection ---------------------------------------------------------

  /// Everything that will actually be armed.
  ///
  /// Critical candidates all go through. Advisory ones are placed most
  /// pressing first, each day taking at most [dailyCap]; one that can wait is
  /// pushed up to [maxShiftDays] to find room, and one that cannot — a day in a
  /// daily run — is dropped, since tomorrow's occurrence says the same thing.
  /// The result is then cut to [pendingBudget], critical first, the rest
  /// soonest first.
  static List<_Candidate> _select(Iterable<_Candidate> candidates) {
    final now = DateTime.now();
    final live = candidates.where((c) => c.when.isAfter(now));

    final critical = live.where((c) => c.critical).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final advisory = live.where((c) => !c.critical).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.when.compareTo(b.when);
      });

    final perDay = <DateTime, int>{};
    final placed = <_Candidate>[];
    for (final candidate in advisory) {
      final shifts = candidate.canWait ? maxShiftDays : 0;
      for (var shift = 0; shift <= shifts; shift++) {
        final at = _shiftDays(candidate.when, shift);
        final day = DateX.dayOnly(at);
        final count = perDay[day] ?? 0;
        if (count >= dailyCap) continue;
        perDay[day] = count + 1;
        placed.add(candidate.at(at));
        break;
      }
    }
    placed.sort((a, b) => a.when.compareTo(b.when));

    final kept = critical.take(pendingBudget).toList();
    return [...kept, ...placed.take(pendingBudget - kept.length)];
  }

  // ---- documents ---------------------------------------------------------

  List<_Candidate> _documents(Vehicle vehicle, AppLocalizations l10n) {
    List<_Candidate> forDocument(DateTime? expiry, String key, String label) =>
        [
          if (expiry != null)
            for (final lead in documentLeadDays)
              _Candidate(
                key: '$key-$lead',
                category: ReminderCategory.documents,
                title: l10n.raw('notifDocumentTitle'),
                body: '$label — ${l10n.fmt('remainingDays', {'n': lead})}',
                when: _atReminderHour(_dayPlus(expiry, -lead)),
                payload: key,
              ),
        ];

    return [
      ...forDocument(
        vehicle.licenseExpiry,
        'doc-license-${vehicle.id}',
        l10n.carLicense,
      ),
      ...forDocument(
        vehicle.insuranceExpiry,
        'doc-insurance-${vehicle.id}',
        l10n.carInsurance,
      ),
    ];
  }

  // ---- booked services ---------------------------------------------------

  /// The day before, the morning of, and the day after while still unconfirmed.
  ///
  /// **The follow-up is what closes the loop.** A booking the driver kept but
  /// never confirmed stays a booking in the app: its parts never reset, its
  /// milestone never closes, and the service it covered keeps nagging as due.
  /// A booking that was confirmed, moved or deleted is simply absent from the
  /// list below, so none of its three reminders re-arm.
  List<_Candidate> _bookings(AppLocalizations l10n) => [
    for (final booking in _ref.read(scheduledRecordsProvider))
      if (booking.scheduledDate case final date?) ...[
        _Candidate(
          key: 'booking-${booking.id}-eve',
          category: ReminderCategory.bookings,
          title: l10n.raw('notifBookingTomorrowTitle'),
          body: _bookingBody(booking, l10n),
          when: _atHour(_dayPlus(date, -1), bookingEveHour),
          payload: 'booking-${booking.id}',
        ),
        _Candidate(
          key: 'booking-${booking.id}-day',
          category: ReminderCategory.bookings,
          title: l10n.raw('notifBookingTodayTitle'),
          body: _bookingBody(booking, l10n),
          when: _atHour(date, bookingDayHour),
          payload: 'booking-${booking.id}',
        ),
        _Candidate(
          key: 'booking-${booking.id}-followup',
          category: ReminderCategory.bookings,
          title: l10n.raw('notifBookingFollowUpTitle'),
          body: l10n.fmt('notifBookingFollowUpBody', {
            'title': _bookingBody(booking, l10n),
          }),
          when: _atReminderHour(_dayPlus(date, 1)),
          payload: 'booking-${booking.id}',
          critical: false,
          priority: _priorityBookingFollowUp,
          canWait: true,
        ),
      ],
  ];

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

  /// The next [routineOccurrences] slots of each check's cadence.
  ///
  /// **Measured from a stored start day, never from now.** This used to start
  /// each check `offsetDays` after the moment of scheduling — and scheduling
  /// runs on every launch and every odometer change. A driver who opened the
  /// app every couple of days had the three-day coolant reminder pushed three
  /// days out again each time, so it never arrived at all: the more someone
  /// used the app, the less it reminded them. The start day is now stored the
  /// first time and every later pass lands on the same instants.
  Future<List<_Candidate>> _routineChecks(AppLocalizations l10n) async {
    final today = DateX.today();
    final candidates = <_Candidate>[];
    for (final check in RoutineCheck.values) {
      final anchor = await _anchor(
        check.reminderKey,
        _dayPlus(today, check.offsetDays),
      );
      for (final slot in _cadence(
        anchor,
        check.everyDays,
        routineOccurrences,
      )) {
        candidates.add(
          _Candidate(
            key: '${check.reminderKey}-${_dayStamp(slot)}',
            category: ReminderCategory.routine,
            title: l10n.raw(check.titleKey),
            body: l10n.raw(check.bodyKey),
            when: slot,
            payload: check.reminderKey,
            critical: false,
            priority: _priorityRoutine,
            canWait: true,
          ),
        );
      }
    }
    return candidates;
  }

  // ---- seasonal checks ---------------------------------------------------

  /// The next occurrence of each season's check — this year's while it is
  /// still ahead, next year's once it has passed. One each: the next pass after
  /// it fires arms the following year.
  List<_Candidate> _seasonalChecks(AppLocalizations l10n) {
    final now = DateTime.now();
    final candidates = <_Candidate>[];
    for (final check in SeasonalCheck.values) {
      final thisYear = _atReminderHour(
        DateTime(now.year, check.month, check.day),
      );
      final when = thisYear.isAfter(now)
          ? thisYear
          : _atReminderHour(DateTime(now.year + 1, check.month, check.day));
      candidates.add(
        _Candidate(
          key: '${check.reminderKey}-${when.year}',
          category: ReminderCategory.seasonal,
          title: l10n.raw(check.titleKey),
          body: l10n.raw(check.bodyKey),
          when: when,
          payload: check.reminderKey,
          critical: false,
          priority: _prioritySeasonal,
          canWait: true,
        ),
      );
    }
    return candidates;
  }

  // ---- odometer ----------------------------------------------------------

  /// "Update the odometer" once a reading is two weeks old, weekly after.
  ///
  /// Every distance-based reminder in the app — services and all seventeen
  /// wear parts — is measured against the last reading. A reading a month old
  /// makes a car that has driven 2,000 km look parked, and every one of those
  /// reminders goes quiet while being wrong. This is the one that keeps the
  /// rest honest.
  ///
  /// Anchored to the reading itself, which every fuel log, service log and
  /// odometer update refreshes. A vehicle from before that field was recorded
  /// gets a stored start day instead, so it too lands on fixed instants.
  Future<List<_Candidate>> _odometerNudges(
    Vehicle vehicle,
    AppLocalizations l10n,
  ) async {
    final reading = vehicle.odometerUpdatedAt;
    final readDay = reading != null
        ? DateX.dayOnly(reading)
        : await _anchor('odometer-${vehicle.id}', DateX.today());

    return [
      for (final slot in _cadence(
        _dayPlus(readDay, odometerStaleDays),
        odometerRepeatDays,
        odometerOccurrences,
      ))
        _Candidate(
          key: 'odometer-${vehicle.id}-${_dayStamp(slot)}',
          category: ReminderCategory.odometer,
          title: l10n.raw('notifOdometerTitle'),
          body: l10n.fmt('notifOdometerBody', {
            'n': _daysBetween(readDay, slot),
          }),
          when: slot,
          payload: 'odometer-${vehicle.id}',
          critical: false,
          priority: _priorityOdometer,
          canWait: true,
        ),
    ];
  }

  // ---- fuel consumption --------------------------------------------------

  /// Says so when the newest fills are markedly thirstier than the history.
  ///
  /// Consumption creeping up is usually one of the routine checks failing —
  /// soft tyres, a clogged air filter — so the message points there. Compared
  /// only within one kind of fuel: litres and cubic metres are not the same
  /// unit, and a car switched to CNG would otherwise read as a collapse.
  ///
  /// Fires once per rise: pinned to the day after the fill that showed it, so
  /// every later pass arms the same instant until it has passed, and a new fill
  /// that keeps the trend is a new, separate alert.
  List<_Candidate> _fuelEconomy(AppLocalizations l10n) {
    final segments = _ref.read(fuelStatsProvider).segments;
    if (segments.isEmpty) return const [];

    final newest = segments.last;
    final gaseous = newest.log.fuelType.isGaseous;
    final comparable = [
      for (final s in segments)
        if (s.log.fuelType.isGaseous == gaseous && s.distanceKm > 0) s,
    ];
    if (comparable.length < fuelRecentFills * 2) return const [];

    final split = comparable.length - fuelRecentFills;
    final recent = _per100Km(comparable.sublist(split));
    final baseline = _per100Km(comparable.sublist(0, split));
    if (baseline <= 0 || recent < baseline * (1 + fuelRiseThreshold)) {
      return const [];
    }

    return [
      _Candidate(
        key: 'fuel-economy-${newest.log.id}',
        category: ReminderCategory.fuelEconomy,
        title: l10n.raw('notifFuelEconomyTitle'),
        body: l10n.fmt('notifFuelEconomyBody', {
          'pct': ((recent / baseline - 1) * 100).round(),
          'n': fuelRecentFills,
        }),
        when: _atReminderHour(_dayPlus(newest.log.date, 1)),
        payload: 'fuel-economy',
        critical: false,
        priority: _priorityFuelEconomy,
        canWait: true,
      ),
    ];
  }

  /// Weighted by distance, so a long highway tank counts for what it covered
  /// rather than as one vote among short ones.
  static double _per100Km(List<FuelSegment> segments) {
    final km = segments.fold<int>(0, (sum, s) => sum + s.distanceKm);
    final volume = segments.fold<double>(0, (sum, s) => sum + s.litersUsed);
    return km == 0 ? 0 : volume / km * 100;
  }

  // ---- monthly summary ---------------------------------------------------

  /// What the car cost, on the 1st, about the month just gone.
  ///
  /// A local notification's text is fixed when it is armed, so this one is
  /// re-armed whenever fuel, service or expense data changes — and data only
  /// changes inside the app, so by the 1st it holds everything. Last month's is
  /// armed alongside this month's for the hours between midnight and the
  /// reminder hour on the 1st, when "this month" has already rolled over.
  List<_Candidate> _monthlySummaries(AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    return [
      for (final month in [
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ])
        ?_monthlySummary(month, l10n, locale),
    ];
  }

  _Candidate? _monthlySummary(
    DateTime month,
    AppLocalizations l10n,
    String locale,
  ) {
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;

    final fuel = _ref
        .read(fuelLogsProvider)
        .where((l) => inMonth(l.date))
        .fold<double>(0, (sum, l) => sum + l.totalCost);
    final maintenance = _ref
        .read(completedRecordsProvider)
        .where((r) => inMonth(r.date))
        .fold<double>(0, (sum, r) => sum + r.cost);
    final other = _ref
        .read(expensesProvider)
        .where((e) => inMonth(e.date))
        .fold<double>(0, (sum, e) => sum + e.amount);

    final total = fuel + maintenance + other;
    // A month with nothing logged is not a month that cost nothing, and saying
    // "0 EGP" would claim it did.
    if (total <= 0) return null;

    String money(double v) => '${Fmt.money(v, locale)} ${l10n.currency}';
    final parts = [
      money(total),
      if (fuel > 0)
        l10n.fmt('summaryFuel', {'amount': Fmt.money(fuel, locale)}),
      if (maintenance > 0)
        l10n.fmt('summaryMaintenance', {
          'amount': Fmt.money(maintenance, locale),
        }),
      if (other > 0)
        l10n.fmt('summaryOther', {'amount': Fmt.money(other, locale)}),
    ];

    return _Candidate(
      key: 'summary-${month.year}-${month.month}',
      category: ReminderCategory.monthlySummary,
      title: l10n.fmt('notifMonthlySummaryTitle', {
        'month': Fmt.monthYear(month, locale),
      }),
      body: parts.join(' · '),
      when: _atReminderHour(DateTime(month.year, month.month + 1)),
      payload: 'summary',
      critical: false,
      priority: _priorityMonthlySummary,
      canWait: true,
    );
  }

  // ---- parking -----------------------------------------------------------

  /// The move-the-car reminder, at the exact minute the driver asked for.
  List<_Candidate> _parking(AppLocalizations l10n) {
    final pin = _ref.read(parkingLocationProvider);
    final when = pin?.remindAt;
    if (pin == null || when == null) return const [];

    final spot = pin.floorOrSection?.trim() ?? '';
    final body = l10n.raw('notifParkingBody');
    return [
      _Candidate(
        key: 'parking-${pin.id}',
        category: ReminderCategory.parking,
        title: l10n.raw('notifParkingTitle'),
        body: spot.isEmpty ? body : '$spot — $body',
        when: when,
        payload: 'parking',
      ),
    ];
  }

  // ---- services ----------------------------------------------------------

  List<_ReminderPlan> _servicePlans(AppLocalizations l10n, String locale) {
    final plans = <_ReminderPlan>[];
    final prices = _ref.read(priceBookProvider);

    for (final service in _ref.read(upcomingServicesProvider)) {
      if (service.isCompleted) continue;
      // Keyed by the stable phase id, not the dynamically projected target
      // odometer, so the reminder run survives the target drifting when an
      // earlier phase closes off-grid.
      final key = 'service-${service.milestone.id}';
      final estimated = service.estimatedDate;

      // What it will roughly cost, on the reminder itself: the driver deciding
      // whether to book this week wants the number, and it is already known.
      final cost = prices.estimate(service.milestone).midpoint;
      String withCost(String body) => cost <= 0
          ? body
          : '$body · ${l10n.fmt('notifEstimatedCost', {'amount': Fmt.money(cost, locale), 'currency': l10n.currency})}';

      // Both limits, tested together and before either window. `isOverdue` is
      // true the moment the target odometer is passed *or* the projected date
      // is, so neither constraint can be masked by the other still being
      // comfortable.
      if (service.isOverdue) {
        plans.add(
          _ReminderPlan(
            key: '$key-overdue',
            title: l10n.raw('notifServiceOverdueTitle'),
            body: withCost(
              l10n.fmt('alertServiceOverdue', {
                'km': Fmt.int0(service.milestone.targetOdometer, locale),
              }),
            ),
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
            body: withCost(
              l10n.fmt('alertServiceKmRemaining', {
                'km': Fmt.int0(service.milestone.targetOdometer, locale),
                'remaining': Fmt.int0(
                  _atLeastZero(service.kmRemaining),
                  locale,
                ),
              }),
            ),
            from: DateTime.now(),
            everyDays: distanceRepeatDays,
            occurrences: distanceOccurrences,
            urgency: _distanceUrgency(service.kmRemaining),
          ),
        );
        continue;
      }

      if (estimated == null) continue;
      final start = _dayPlus(estimated, -serviceLeadDays);

      plans.add(
        _ReminderPlan(
          key: '$key-date',
          title: l10n.raw('notifServiceTitle'),
          body: withCost(
            l10n.fmt('alertServiceDueSoon', {
              'km': service.milestone.targetOdometer,
            }),
          ),
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
      final start = _dayPlus(due, -serviceLeadDays);

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

  /// A plan's run, as candidates.
  ///
  /// The run is **anchored forward**, never replayed from its start: a window
  /// that opened in the past resumes at the next slot and still gets its full
  /// count. It used to skip past occurrences instead, and a date-driven plan's
  /// last slot is the due date itself — so from that morning on, every
  /// occurrence was in the past and the item armed nothing. The app went quiet
  /// precisely when the service came due.
  ///
  /// Days in a run cannot wait: tomorrow's occurrence already says the same
  /// thing, so a full day drops one rather than piling it onto the next.
  List<_Candidate> _expand(_ReminderPlan plan) {
    final start = _firstSlotFrom(plan.from);
    return [
      for (var i = 0; i < plan.occurrences; i++)
        _Candidate(
          key: '${plan.key}-$i',
          category: ReminderCategory.maintenance,
          title: plan.title,
          body: plan.body,
          when: _shiftDays(start, plan.everyDays * i),
          payload: plan.key,
          critical: false,
          priority: plan.urgency,
        ),
    ];
  }

  /// The stored start day for [key], storing [initial] the first time.
  Future<DateTime> _anchor(String key, DateTime initial) async {
    final store = _ref.read(preferencesStoreProvider);
    final stored = DateTime.tryParse(store.reminderAnchors[key] ?? '');
    if (stored != null) return DateX.dayOnly(stored);
    final day = DateX.dayOnly(initial);
    await store.setReminderAnchor(key, _dayStamp(day));
    return day;
  }

  /// The next [count] slots of a cadence that started on [anchorDay] and
  /// repeats every [everyDays], at the reminder hour, all still ahead.
  ///
  /// Pure arithmetic on the anchor, so every pass yields the same instants: a
  /// slot that has passed is skipped, never re-based from today.
  List<DateTime> _cadence(DateTime anchorDay, int everyDays, int count) {
    final now = DateTime.now();
    final elapsed = _daysBetween(anchorDay, now);
    var step = elapsed <= 0 ? 0 : (elapsed / everyDays).ceil();
    if (!_atReminderHour(_dayPlus(anchorDay, step * everyDays)).isAfter(now)) {
      step++;
    }
    return [
      for (var i = 0; i < count; i++)
        _atReminderHour(_dayPlus(anchorDay, (step + i) * everyDays)),
    ];
  }

  /// The first reminder-hour slot at or after [from] that has not already
  /// passed. A window already open — or long overdue — starts at the next
  /// slot, so a pass at 5 pm does not burn its first occurrence on a morning
  /// that is eight hours gone.
  DateTime _firstSlotFrom(DateTime from) {
    final now = DateTime.now();
    final slot = _atReminderHour(from.isAfter(now) ? from : now);
    return slot.isAfter(now) ? slot : _shiftDays(slot, 1);
  }

  /// Whole days from now until [date], floored at zero.
  static int _daysFromNow(DateTime date) {
    final days = _daysBetween(DateTime.now(), date);
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

  /// How long an item has been past its projected date, in whole days. Zero
  /// when the odometer target has been passed but the date is still ahead.
  static int _daysPast(DateTime? projected) {
    if (projected == null) return 0;
    final days = _daysBetween(projected, DateTime.now());
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

  DateTime _atReminderHour(DateTime d) => _atHour(d, _hour);

  /// The given day at [hour] local, with whatever time of day [d] carried
  /// discarded — a reminder is pinned to a time we chose, not to the minute a
  /// record happened to be saved at.
  static DateTime _atHour(DateTime d, int hour) =>
      DateTime(d.year, d.month, d.day, hour);

  /// [d] moved by [days] calendar days, keeping its time of day.
  ///
  /// **Calendar arithmetic, not `Duration(days:)`.** Egypt keeps daylight
  /// saving, and adding 24-hour blocks across a change lands an hour off —
  /// which at midnight is the previous day. Normalising the day number instead
  /// is exact on either side of the change.
  static DateTime _shiftDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  static DateTime _dayPlus(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [a] to [b], immune to daylight saving: counted
  /// on UTC dates, where every day is 24 hours.
  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static String _dayStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void dispose() => _debounce?.cancel();
}

/// One notification, resolved but not yet armed.
///
/// Held as data so the whole set can be switched, capped and budgeted before
/// anything is handed to the OS.
class _Candidate {
  _Candidate({
    required this.key,
    required this.category,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
    bool? critical,
    this.priority = 0,
    this.canWait = false,
  }) : critical = critical ?? category.critical;

  final String key;
  final ReminderCategory category;
  final String title;
  final String body;
  final DateTime when;
  final String payload;

  /// Exempt from the daily cap and armed first. Defaults to the category's.
  final bool critical;

  /// Lower is more pressing. Only compared among advisory candidates.
  final int priority;

  /// Whether it may be pushed to a later day when its own is full.
  final bool canWait;

  _Candidate at(DateTime when) => _Candidate(
    key: key,
    category: category,
    title: title,
    body: body,
    when: when,
    payload: payload,
    critical: critical,
    priority: priority,
    canWait: canWait,
  );
}

/// One service or part's reminder run, before it is expanded into candidates.
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

  /// Lower is more pressing — see the priority bands on [ReminderScheduler].
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
/// service log — re-arm the distance-triggered reminders immediately. The
/// spending totals are here for the monthly summary, whose text is fixed when
/// it is armed and so has to be re-armed whenever a figure in it changes.
final reminderSignatureProvider = Provider<int>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  final services = ref.watch(upcomingServicesProvider);
  final parts = ref.watch(allPartsHealthProvider);
  final bookings = ref.watch(scheduledRecordsProvider);
  final enabled = ref.watch(notificationsEnabledProvider);
  final prefs = ref.watch(reminderPrefsProvider);
  final fuelLogs = ref.watch(fuelLogsProvider);
  final expenses = ref.watch(expensesProvider);
  final completed = ref.watch(completedRecordsProvider);
  final parking = ref.watch(parkingLocationProvider);

  return Object.hash(
    vehicle?.id,
    vehicle?.currentOdometer,
    vehicle?.odometerUpdatedAt,
    vehicle?.licenseExpiry,
    vehicle?.insuranceExpiry,
    Object.hashAll(services.map(_serviceFingerprint)),
    Object.hashAll(parts.map(_partFingerprint)),
    Object.hashAll(bookings.map(_bookingFingerprint)),
    enabled,
    prefs,
    Object.hashAll(fuelLogs.map((l) => Object.hash(l.id, l.totalCost))),
    Object.hashAll(expenses.map((e) => Object.hash(e.id, e.amount, e.date))),
    Object.hashAll(completed.map((r) => Object.hash(r.id, r.cost, r.date))),
    Object.hash(parking?.id, parking?.remindAt, parking?.floorOrSection),
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

/// Exactly what the reminders are built from. Booking, moving or confirming an
/// appointment changes this; editing its cost does not.
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
