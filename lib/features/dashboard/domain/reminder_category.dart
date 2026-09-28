/// Every kind of reminder the app arms, and whether the driver can switch it
/// off on its own.
///
/// **One switch per kind, because the alternative is losing all of them.** A
/// driver tired of one reminder reaches for the only switch there is, and with
/// a single master switch that silences the licence renewal along with the
/// fortnightly tyre check. The renewal is the one with a fine behind it.
///
/// [critical] marks the reminders that are exempt from the daily cap and armed
/// first under the pending budget: a legal deadline, an appointment made with a
/// third party, a parking meter the driver set themselves. Everything else is
/// advice, and advice can wait a day.
enum ReminderCategory {
  documents(
    prefKey: 'pref_reminders_documents',
    titleKey: 'reminderCatDocuments',
    hintKey: 'reminderCatDocumentsHint',
    critical: true,
  ),
  bookings(
    prefKey: 'pref_reminders_bookings',
    titleKey: 'reminderCatBookings',
    hintKey: 'reminderCatBookingsHint',
    critical: true,
  ),
  maintenance(
    prefKey: 'pref_reminders_maintenance',
    titleKey: 'reminderCatMaintenance',
    hintKey: 'reminderCatMaintenanceHint',
  ),

  /// Keeps the key the routine switch has always been stored under, so a
  /// driver who turned it off before stays off.
  routine(
    prefKey: 'pref_routine_checks_enabled',
    titleKey: 'routineChecks',
    hintKey: 'routineChecksHint',
  ),
  seasonal(
    prefKey: 'pref_reminders_seasonal',
    titleKey: 'reminderCatSeasonal',
    hintKey: 'reminderCatSeasonalHint',
  ),
  odometer(
    prefKey: 'pref_reminders_odometer',
    titleKey: 'reminderCatOdometer',
    hintKey: 'reminderCatOdometerHint',
  ),
  fuelEconomy(
    prefKey: 'pref_reminders_fuel_economy',
    titleKey: 'reminderCatFuelEconomy',
    hintKey: 'reminderCatFuelEconomyHint',
  ),
  monthlySummary(
    prefKey: 'pref_reminders_monthly_summary',
    titleKey: 'reminderCatMonthlySummary',
    hintKey: 'reminderCatMonthlySummaryHint',
  ),

  /// Set per pin in the parking sheet, not here: the driver asks for it at the
  /// moment they park, so a standing switch would only be a second place to
  /// say the same thing.
  parking(
    prefKey: null,
    titleKey: 'notifParkingTitle',
    hintKey: 'notifParkingTitle',
    critical: true,
  );

  const ReminderCategory({
    required this.prefKey,
    required this.titleKey,
    required this.hintKey,
    this.critical = false,
  });

  /// Where the on/off choice is stored. Null for a category with no switch.
  final String? prefKey;

  final String titleKey;
  final String hintKey;
  final bool critical;

  bool get isToggleable => prefKey != null;

  /// The ones that get a switch in settings, in the order they are listed.
  static List<ReminderCategory> get toggleable =>
      values.where((c) => c.isToggleable).toList(growable: false);
}
