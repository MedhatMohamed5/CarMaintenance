/// Checks that fall due on the calendar alone, with nothing in the app to
/// predict them from.
///
/// **Everything else the scheduler arms is derived from data the driver
/// supplies**: a service target comes from logged history and an odometer
/// reading, a part's remaining life from the distance since it was replaced.
/// Coolant, tyre pressure and oil level are not like that. They drift with
/// heat, a slow leak or a weeping seal, and a car can lose all three while
/// parked — so no amount of odometer history will ever raise them. They are
/// also the three that strand a driver on the ring road, which is why they are
/// the three worth a standing reminder rather than a longer list nobody reads.
///
/// The cadences are deliberately unequal and the offsets deliberately
/// staggered: three reminders arriving on the same morning are one reminder the
/// driver dismisses, and the fortnightly pair would otherwise collide with the
/// monthly one every second month.
enum RoutineCheck {
  coolant(
    titleKey: 'routineCoolantTitle',
    bodyKey: 'routineCoolantBody',
    everyDays: 14,
    offsetDays: 3,
  ),
  tyrePressure(
    titleKey: 'routineTyresTitle',
    bodyKey: 'routineTyresBody',
    everyDays: 14,
    offsetDays: 8,
  ),
  oilLevel(
    titleKey: 'routineOilTitle',
    bodyKey: 'routineOilBody',
    everyDays: 30,
    offsetDays: 15,
  );

  const RoutineCheck({
    required this.titleKey,
    required this.bodyKey,
    required this.everyDays,
    required this.offsetDays,
  });

  final String titleKey;
  final String bodyKey;

  /// How often the reminder repeats.
  final int everyDays;

  /// Days after a reschedule before this check's first reminder, so the three
  /// never land together.
  final int offsetDays;

  /// Stable id for the reminder run, independent of position in the enum.
  String get reminderKey => 'routine-$name';
}
