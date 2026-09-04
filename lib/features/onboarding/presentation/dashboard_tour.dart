import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/coach_mark.dart';
import 'providers/onboarding_providers.dart';

/// The widgets the guided tour points at.
///
/// **Static keys, because each of these mounts exactly once.** The dashboard
/// lives in the shell's `IndexedStack` and the navigation controls belong to
/// the shell itself, so there is never a second instance competing for a key.
///
/// Keeping them here rather than threading keys down through constructors means
/// a screen only has to tag a widget; it never has to know a tour exists.
abstract final class TourKeys {
  static final vehicle = GlobalKey(debugLabel: 'tour-vehicle');
  static final vehicleSwitcher = GlobalKey(debugLabel: 'tour-vehicle-switcher');
  static final quickActions = GlobalKey(debugLabel: 'tour-quick-actions');
  static final nextService = GlobalKey(debugLabel: 'tour-next-service');
  static final settings = GlobalKey(debugLabel: 'tour-settings');

  /// **The bar and the rail get a key each, not one key between them.** They
  /// are opposite branches of the shell's width test, so only one is ever
  /// mounted — but a window dragged across the 900 pt breakpoint rebuilds one
  /// into the other, and a single `GlobalKey` migrating between two different
  /// widget types in two different Scaffold slots is exactly the shape that
  /// throws "multiple widgets used the same GlobalKey". Two keys and two steps
  /// cost nothing: the unmounted one is dropped before the tour starts.
  static final navBar = GlobalKey(debugLabel: 'tour-nav-bar');
  static final navRail = GlobalKey(debugLabel: 'tour-nav-rail');
}

/// The tour itself, in reading order down the dashboard and then out to the
/// shell.
///
/// Six stops as the driver counts them — the two navigation entries are one
/// stop wearing two layouts. Six is the ceiling, not a target: past about that
/// a tour stops being an introduction and becomes a manual nobody finishes, and
/// every extra step is one more chance to hit Skip and miss the ones that
/// mattered.
///
/// Steps whose target is absent — no vehicle yet, a card with nothing to show —
/// are dropped by [showCoachMarks], so this list does not have to be conditional.
List<CoachStep> dashboardTourSteps() => [
  CoachStep(
    targetKey: TourKeys.vehicle,
    titleKey: 'tourVehicleTitle',
    bodyKey: 'tourVehicleBody',
    icon: AppIcons.vehicle,
    color: AppColors.cyan,
  ),
  CoachStep(
    targetKey: TourKeys.vehicleSwitcher,
    titleKey: 'tourSwitchTitle',
    bodyKey: 'tourSwitchBody',
    icon: Icons.swap_horiz_rounded,
    color: AppColors.indigo,
    shape: CoachHoleShape.circle,
    inflate: 4,
  ),
  CoachStep(
    targetKey: TourKeys.quickActions,
    titleKey: 'tourActionsTitle',
    bodyKey: 'tourActionsBody',
    icon: Icons.bolt_rounded,
    color: AppColors.green,
  ),
  CoachStep(
    targetKey: TourKeys.nextService,
    titleKey: 'tourServiceTitle',
    bodyKey: 'tourServiceBody',
    icon: AppIcons.schedule,
    color: AppColors.amber,
  ),
  // Same copy either way — the compact bar and the wide-layout rail are the
  // same idea wearing different geometry.
  CoachStep(
    targetKey: TourKeys.navBar,
    titleKey: 'tourNavTitle',
    bodyKey: 'tourNavBody',
    icon: AppIcons.home,
    color: AppColors.teal,
    inflate: 2,
  ),
  CoachStep(
    targetKey: TourKeys.navRail,
    titleKey: 'tourNavTitle',
    bodyKey: 'tourNavBody',
    icon: AppIcons.home,
    color: AppColors.teal,
    inflate: 2,
  ),
  CoachStep(
    targetKey: TourKeys.settings,
    titleKey: 'tourSettingsTitle',
    bodyKey: 'tourSettingsBody',
    icon: Icons.tune_rounded,
    color: AppColors.purple,
    shape: CoachHoleShape.circle,
    inflate: 4,
  ),
];

/// Decides *when* the dashboard tour runs. Passes [child] straight through.
///
/// Wrapped around the dashboard body rather than mounted next to it so the
/// trigger dies with the screen it points at: nothing can start a tour over a
/// dashboard that is not there.
class DashboardTourStarter extends ConsumerStatefulWidget {
  const DashboardTourStarter({
    super.key,
    required this.hasVehicle,
    required this.child,
  });

  /// **The first run waits for a car.** On a fresh install the dashboard is an
  /// empty state: no hero card, no quick actions, nothing due. A tour there
  /// would spotlight two icons, mark itself seen and never come back. Once the
  /// driver adds their first vehicle the screen is full and the tour is worth
  /// running.
  final bool hasVehicle;

  final Widget child;

  @override
  ConsumerState<DashboardTourStarter> createState() =>
      _DashboardTourStarterState();
}

class _DashboardTourStarterState extends ConsumerState<DashboardTourStarter> {
  /// Long enough for the dashboard's entrance ladder to finish. Measuring a
  /// card while it is still fading and rising up its last few pixels gives a
  /// rect that is wrong by the time the spotlight paints it.
  static const _settle = Duration(milliseconds: 800);

  /// A replay is requested from Settings, which then pops back to the
  /// dashboard. This is the pop, plus a frame or two for layout to land.
  static const _afterPop = Duration(milliseconds: 320);

  /// How long a blocked start keeps waiting for the screen to clear.
  ///
  /// **A start that cannot run right now is deferred, never dropped.** The
  /// automatic pass fires the moment the first vehicle is saved, which is while
  /// the vehicle sheet is still on screen — and on a first run the driver
  /// frequently opens another sheet straight after it. Sampling the screen once
  /// and giving up meant the introduction was lost for the whole session, and
  /// since `hasVehicle` only turns true once per process, nothing could ask for
  /// it again until the next cold start. That is the whole of the "the tour
  /// only shows the second time you open the app" bug.
  ///
  /// Bounded rather than indefinite: past half a minute the driver is doing
  /// something else, and a tour that ambushes them then is worse than one that
  /// waits for the next launch.
  static const _clearWindow = Duration(seconds: 30);

  static const _clearPoll = Duration(milliseconds: 400);

  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
  }

  @override
  void didUpdateWidget(DashboardTourStarter old) {
    super.didUpdateWidget(old);
    // **Not an edge test.** `hasVehicle` goes false → true exactly once per
    // process — the moment the first car is saved — so testing for that
    // transition gave the tour a single attempt and no way to ask for another.
    // Re-armed on every update, a start that finds the screen busy is retried
    // as soon as the dashboard rebuilds. The extra calls cost nothing:
    // `_maybeAutoStart` returns on `tourSeen`, and `_start` returns on
    // `_running`.
    _maybeAutoStart();
  }

  void _maybeAutoStart() {
    if (!widget.hasVehicle || ref.read(tourSeenProvider)) return;
    _start(after: _settle);
  }

  Future<void> _start({required Duration after}) async {
    if (_running) return;
    _running = true;
    try {
      await Future<void>.delayed(after);

      // Wait for the screen rather than test it once; see [_clearWindow].
      final deadline = DateTime.now().add(_clearWindow);
      while (mounted && !_isClear && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(_clearPoll);
      }
      if (!mounted || !_isClear) return;

      // **Only a tour that appeared counts as one the driver has seen.** If
      // every target is missing `showCoachMarks` shows nothing, and marking it
      // seen there would spend a flag that is never cleared on a tour that
      // never happened.
      final shown = await showCoachMarks(context, steps: dashboardTourSteps());
      if (!mounted || !shown) return;
      await ref.read(tourSeenProvider.notifier).markSeen();
    } finally {
      _running = false;
    }
  }

  /// Whether the dashboard is the top of the screen.
  ///
  /// Two navigators can be holding a route above it: the branch navigator
  /// (Settings, Notes, Analytics) and the root one (every sheet and dialog in
  /// the app opens there). A tour that starts over either cuts holes where its
  /// targets *used to be*.
  bool get _isClear =>
      ModalRoute.of(context)?.isCurrent == true &&
      !Navigator.of(context, rootNavigator: true).canPop();

  @override
  Widget build(BuildContext context) {
    // Fires while this screen sits underneath Settings, which is exactly when
    // the request is made — the delay above covers the pop back to here.
    ref.listen<int>(
      tourReplayProvider,
      (_, _) => _start(after: _afterPop + AppDurations.routeExit),
    );
    return widget.child;
  }
}
