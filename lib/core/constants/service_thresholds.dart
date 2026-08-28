/// Numbers that encode a *rule* about upcoming work, rather than a number that
/// happens to appear in one calculation.
///
/// Pure Dart on purpose — the domain layer imports this, so it must not reach
/// for Flutter.
library;

/// When a service stops being "later" and starts being "soon".
///
/// This threshold was declared three separate times before it lived here —
/// twice as `dueSoonKm`/`dueSoonDays` on two different entities, once as
/// `serviceLeadDays` on the reminder scheduler. They agreed by luck. Changing
/// the driver's warning window meant finding all three, and the notification
/// silently disagreeing with the badge is exactly the kind of bug nobody
/// reports because each screen looks correct on its own.
abstract final class ServiceThresholds {
  /// Distance still to run before the service is called due soon.
  static const int dueSoonKm = 500;

  /// Or, at the driver's own measured pace, this many days out.
  static const int dueSoonDays = 14;
}

/// Bounds on anything the app projects forward from a measured pace.
abstract final class ProjectionLimits {
  /// A century, in days, and the furthest any estimate may reach in either
  /// direction.
  ///
  /// A pace close to zero sends `remainingKm / pace` towards infinity, and
  /// `Duration(days:)` on that throws before anything gets a chance to look
  /// wrong. Clamping keeps a barely-driven car showing an absurd date instead
  /// of crashing the screen — absurd is readable, a crash is not.
  static const int horizonDays = 36500;
}
