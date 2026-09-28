/// Checks that fall due with the season, once a year each.
///
/// Egypt's calendar is hard on a car in three distinct ways, and each has a
/// short list of things it wears out:
///
/// * **Khamaseen** — the spring dust storms clog the air filter and the cabin
///   filter in a matter of days.
/// * **Summer** — heat is what kills batteries here, and it is when the AC and
///   the cooling system are pushed hardest.
/// * **Winter** — the first rain finds worn wiper blades, an empty washer
///   reservoir and bald tyres.
///
/// Dated a little ahead of each season rather than on its first day: the point
/// is to check before the weather arrives, not after the car has already failed
/// in it.
enum SeasonalCheck {
  khamaseen(
    month: 3,
    day: 15,
    titleKey: 'seasonKhamaseenTitle',
    bodyKey: 'seasonKhamaseenBody',
  ),
  summer(
    month: 5,
    day: 1,
    titleKey: 'seasonSummerTitle',
    bodyKey: 'seasonSummerBody',
  ),
  winter(
    month: 11,
    day: 1,
    titleKey: 'seasonWinterTitle',
    bodyKey: 'seasonWinterBody',
  );

  const SeasonalCheck({
    required this.month,
    required this.day,
    required this.titleKey,
    required this.bodyKey,
  });

  final int month;
  final int day;
  final String titleKey;
  final String bodyKey;

  /// Stable id for the reminder, independent of position in the enum.
  String get reminderKey => 'seasonal-$name';
}
