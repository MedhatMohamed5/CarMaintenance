import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/platform/reminder_notifier.dart';
import '../../../../core/utils/formatters.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';

/// Fires local notifications ahead of every deadline the app knows about.
///
/// Runs as a listener rather than on a timer: whenever the underlying data
/// changes (a fill is logged, a part is reset, a vehicle is edited) the whole
/// reminder set is recomputed and re-scheduled. Notification ids are derived
/// from a stable domain key, so rescheduling replaces rather than duplicates.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  /// Reminder lead times, in days before the deadline.
  static const List<int> documentLeadDays = [30, 7, 1];
  static const int serviceLeadDays = 7;

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

    await notifier.cancelAll();
    if (vehicle == null) return;

    await _scheduleDocuments(vehicle, notifier, l10n, locale);
    await _scheduleServices(vehicle, notifier, l10n);
    await _scheduleParts(notifier, l10n);
  }

  Future<void> _scheduleDocuments(
    Vehicle vehicle,
    ReminderNotifier notifier,
    AppLocalizations l10n,
    String locale,
  ) async {
    Future<void> forDocument(DateTime? expiry, String key, String label) async {
      if (expiry == null) return;
      for (final lead in documentLeadDays) {
        final when = _at9am(expiry.subtract(Duration(days: lead)));
        await notifier.schedule(
          id: reminderIdFor('$key-$lead'),
          title: l10n.raw('notifDocumentTitle'),
          body: '$label — ${l10n.fmt('remainingDays', {'n': lead})}',
          when: when,
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

  Future<void> _scheduleServices(
    Vehicle vehicle,
    ReminderNotifier notifier,
    AppLocalizations l10n,
  ) async {
    for (final service in _ref.read(upcomingServicesProvider)) {
      final estimated = service.estimatedDate;
      if (estimated == null) continue;
      await notifier.schedule(
        id: reminderIdFor('service-${service.targetOdometer}'),
        title: l10n.raw('notifServiceTitle'),
        body: l10n.fmt('alertServiceDueSoon', {'km': service.targetOdometer}),
        when: _at9am(estimated.subtract(const Duration(days: serviceLeadDays))),
        payload: 'service-${service.targetOdometer}',
      );
    }
  }

  Future<void> _scheduleParts(
    ReminderNotifier notifier,
    AppLocalizations l10n,
  ) async {
    for (final health in _ref.read(allPartsHealthProvider)) {
      // Only nag about parts that are actually approaching their limit.
      if (health.status == HealthStatus.healthy) continue;
      final due = health.estimatedDueDate;
      if (due == null) continue;
      await notifier.schedule(
        id: reminderIdFor('part-${health.part.id}'),
        title: l10n.raw('notifPartTitle'),
        body: l10n.fmt('alertPartDueSoon', {
          'part': l10n.raw(health.part.l10nKey),
        }),
        when: _at9am(due.subtract(const Duration(days: serviceLeadDays))),
        payload: 'part-${health.part.id}',
      );
    }
  }

  /// Reminders land mid-morning: late enough not to wake anyone, early enough
  /// to act on the same day.
  static DateTime _at9am(DateTime d) {
    final day = DateX.dayOnly(d);
    return DateTime(day.year, day.month, day.day, 9);
  }

  void dispose() => _debounce?.cancel();
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Watches everything a reminder could depend on and re-schedules when any of
/// it moves. Kept alive for the app's lifetime by a `ref.watch` in the shell.
final reminderSyncProvider = Provider<void>((ref) {
  ref.watch(selectedVehicleProvider);
  ref.watch(upcomingServicesProvider);
  ref.watch(allPartsHealthProvider);
  ref.watch(notificationsEnabledProvider);
  ref.read(reminderSchedulerProvider).scheduleSoon();
});
