/// Motion timings, named for the *role* the motion plays rather than its
/// length. Two animations share a constant when they are the same gesture, not
/// when they happen to run for the same number of milliseconds.
///
/// That distinction is the whole point of the file. Before it, the stagger
/// between rows of a list was written as six different values — 35, 40, 45, 50,
/// 55 and 60 ms — across six screens, and none of the differences were a
/// decision anyone made. Meanwhile the splash screen's minimum on-screen time
/// and a counter's count-up both happened to be 900 ms while meaning nothing to
/// each other; those stay apart, deliberately.
///
/// Adding a timing here is only worth it if you can name the role. If the
/// answer is "it's 250 because that looked right in this one place", leave it
/// where it is.
abstract final class AppDurations {
  /// A section or card fading and rising into place on first build.
  static const Duration entrance = Duration(milliseconds: 320);

  /// One row inside a list. Shorter than [entrance] because many of them
  /// overlap on screen at once.
  static const Duration entranceItem = Duration(milliseconds: 300);

  /// Added per item so a list arrives as a ladder rather than a block.
  static const Duration entranceStep = Duration(milliseconds: 45);

  /// Index at which the stagger stops growing. Without a cap the twentieth row
  /// of a list would sit blank for most of a second waiting for its turn.
  static const int entranceStepCap = 8;

  /// A control changing appearance because its state changed — selected,
  /// enabled, expanded chevron colour, theme swap.
  static const Duration stateChange = Duration(milliseconds: 200);

  /// The press-down of a tappable surface. Deliberately the shortest timing in
  /// the app: anything slower reads as lag rather than as a response.
  static const Duration press = Duration(milliseconds: 140);

  /// A panel growing or collapsing, plus whatever cross-fades or rotates as
  /// part of that same gesture.
  static const Duration expand = Duration(milliseconds: 260);

  /// A number counting up, or a bar filling to its value. Long on purpose — for
  /// these the motion *is* the reading, not decoration on top of it.
  static const Duration valueFill = Duration(milliseconds: 900);

  /// Pushing a route.
  static const Duration routeEnter = Duration(milliseconds: 220);

  /// Popping one. Shorter than [routeEnter]: going back should not feel like
  /// another journey.
  static const Duration routeExit = Duration(milliseconds: 190);
}
