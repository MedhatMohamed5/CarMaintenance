import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/dealers/presentation/providers/dealer_providers.dart';
import '../../features/dealers/presentation/screens/workshops_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/analytics/presentation/screens/export_report_screen.dart';
import '../../features/analytics/presentation/screens/insights_forecast_screen.dart';
import '../../features/dealers/presentation/widgets/dealer_card.dart';
import '../../features/emergency/presentation/widgets/emergency_section.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/fuel/presentation/screens/fuel_form_sheet.dart';
import '../../features/fuel/presentation/screens/fuel_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_log_screen.dart';
import '../../features/maintenance/presentation/screens/service_schedule_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../constants/app_durations.dart';
import '../localization/app_localizations.dart';
import '../utils/screen_insets.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/side_nav_rail.dart';

/// Fade-through for every pushed route.
///
/// The outgoing screen fades and settles back a hair while the incoming one
/// fades and rises to meet it — the Material "fade through" idiom, which reads
/// as a change of context rather than a slide across a map.
///
/// **Ghosting is prevented by the opaque ground, not by the curve.** A pushed
/// route with a transparent scaffold lets the previous screen show through for
/// the length of the transition, which is what produced the double-image. Every
/// page below is wrapped in [_RouteSurface], which paints the theme background
/// under the child so the two screens never composite together.
class _FadeThroughPage extends CustomTransitionPage<void> {
  _FadeThroughPage({required Widget child, super.key})
    : super(
        transitionDuration: AppDurations.routeEnter,
        reverseTransitionDuration: AppDurations.routeExit,
        // Opaque: Flutter can stop painting the route underneath once this one
        // has covered it, which is both the fix for ghosting and one fewer
        // layer to composite.
        opaque: true,
        barrierDismissible: false,
        child: RepaintBoundary(child: _RouteSurface(child: child)),
        transitionsBuilder: _fadeThrough,
      );

  static Widget _fadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The two halves do not overlap. The outgoing screen is fully transparent
    // by 30% of the curve; the incoming one does not start appearing until
    // 30%. That gap is what removes the double-image — at no point are both
    // painted at a visible opacity.
    // **`CurveTween.animate`, never `CurvedAnimation`.** A `CurvedAnimation`
    // attaches a listener to its parent and has to be disposed; this builder is
    // called on every frame of the transition, so each push leaked one per
    // frame for the life of the route. `Animatable.animate` returns a lazy view
    // that reads the parent on demand and registers nothing, so there is
    // nothing to leak and nothing to remember to release.
    final fadeIn = CurveTween(
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    ).animate(animation);

    final rise = Tween<Offset>(
      begin: const Offset(0, 0.012),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);

    final fadeOut = Tween<double>(begin: 1, end: 0)
        .chain(CurveTween(curve: const Interval(0, 0.3, curve: Curves.easeIn)))
        .animate(secondaryAnimation);

    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(position: rise, child: child),
      ),
    );
  }
}

/// Paints the theme's own background beneath a routed screen.
///
/// Most screens set `backgroundColor: Colors.transparent` so the shell's
/// ambient backdrop shows through. That is right inside the shell and wrong
/// during a push, where transparency means the previous screen is visible
/// underneath. This restores an opaque ground without any screen having to know
/// it is being transitioned.
class _RouteSurface extends StatelessWidget {
  const _RouteSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}

/// Full-screen modal: rises from the bottom rather than fading in place, which
/// is what tells the user this is a task laid over the app rather than a move
/// within it. Same opaque ground as [_FadeThroughPage].
class _ModalPage extends CustomTransitionPage<void> {
  const _ModalPage({required super.child})
    : super(
        transitionDuration: AppDurations.routeEnter,
        reverseTransitionDuration: AppDurations.routeExit,
        opaque: true,
        transitionsBuilder: _slideUp,
      );

  static Widget _slideUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    // Same reason as `_fadeThrough`: a lazy view rather than a listener that
    // would have to be disposed.
    opacity: CurveTween(curve: Curves.easeOut).animate(animation),
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation),
      child: RepaintBoundary(child: _RouteSurface(child: child)),
    ),
  );
}

/// Pushed routes fade through. Branch roots do not — see [_branchPage].
CustomTransitionPage<void> _fadeThroughPage(Widget child, {LocalKey? key}) =>
    _FadeThroughPage(key: key, child: child);

/// A tab's root screen.
///
/// Tab switches are an `IndexedStack` swap, not a push: both branches are
/// already built and alive. Animating here would cross-fade two live subtrees
/// every time the user taps the bar, so the transition lives in
/// [AppShellScaffold] instead, applied once around the shell body.
NoTransitionPage<void> _branchPage(Widget child) =>
    NoTransitionPage<void>(child: RepaintBoundary(child: child));

class AppRoutes {
  const AppRoutes._();

  static const String dashboard = '/';
  static const String maintenance = '/maintenance';
  static const String fuel = '/fuel';
  static const String expenses = '/expenses';
  static const String workshops = '/workshops';
  static const String emergency = '/emergency';

  static const String analytics = '/analytics';
  static const String forecast = '/forecast';
  static const String settings = '/settings';
  static const String schedule = '/maintenance/schedule';

  static const String addFuel = '/add-fuel';
  static const String dealerDetails = '/dealer-details';
  static const String exportReport = '/export-report';

  static String dealerDetailsPath(String id) => '$dealerDetails/$id';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dash');
final _maintenanceNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'maint');
final _fuelNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'fuel');
final _expensesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'exp');
final _workshopsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'work');
final _emergencyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'emer');

/// Branch navigators in shell order, so a tab tap can reach the navigator it
/// is about to activate.
final _branchNavigatorKeys = <GlobalKey<NavigatorState>>[
  _dashboardNavigatorKey,
  _maintenanceNavigatorKey,
  _fuelNavigatorKey,
  _expensesNavigatorKey,
  _workshopsNavigatorKey,
  _emergencyNavigatorKey,
];

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                pageBuilder: (context, state) =>
                    _branchPage(const HomeDashboardScreen()),
                routes: [
                  GoRoute(
                    path: 'analytics',
                    pageBuilder: (context, state) => _fadeThroughPage(
                      const AnalyticsScreen(),
                      key: state.pageKey,
                    ),
                  ),
                  GoRoute(
                    path: 'forecast',
                    pageBuilder: (context, state) => _fadeThroughPage(
                      const InsightsForecastScreen(),
                      key: state.pageKey,
                    ),
                  ),
                  // Owned by the router, not pushed imperatively: a route the
                  // shell cannot see is a route `goBranch` cannot pop.
                  GoRoute(
                    path: 'settings',
                    pageBuilder: (context, state) => _fadeThroughPage(
                      const SettingsScreen(),
                      key: state.pageKey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _maintenanceNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.maintenance,
                pageBuilder: (context, state) =>
                    _branchPage(const MaintenanceLogScreen()),
                routes: [
                  GoRoute(
                    path: 'schedule',
                    pageBuilder: (context, state) => _fadeThroughPage(
                      const ServiceScheduleScreen(),
                      key: state.pageKey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _fuelNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.fuel,
                pageBuilder: (context, state) =>
                    _branchPage(const FuelScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _expensesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                pageBuilder: (context, state) =>
                    _branchPage(const ExpensesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _workshopsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.workshops,
                pageBuilder: (context, state) =>
                    _branchPage(const WorkshopsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _emergencyNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.emergency,
                pageBuilder: (context, state) =>
                    _branchPage(const EmergencyScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addFuel,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const _ModalPage(child: AddFuelScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.dealerDetails}/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fadeThroughPage(
          DealerDetailsScreen(dealerId: state.pathParameters['id'] ?? ''),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: AppRoutes.exportReport,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const _ModalPage(child: ExportReportScreen()),
      ),
    ],
    errorPageBuilder: (context, state) => _fadeThroughPage(
      RouteErrorScreen(error: state.error),
      key: state.pageKey,
    ),
  );
});

/// Fades the shell body in when the active tab changes.
///
/// **One subtree, never two.** An `AnimatedSwitcher` would keep the outgoing
/// tab mounted alongside the incoming one for the length of the fade, which is
/// exactly the stacking artifact this replaces — and doubly wasteful here,
/// because `StatefulShellRoute.indexedStack` has already built and kept every
/// branch. The `IndexedStack` swaps instantly; only the opacity of the single
/// visible child is animated, so nothing ever overlaps.
///
/// Short and opacity-only. It starts part-way up rather than from zero, so the
/// new tab is legible on the first frame and the fade reads as a settle rather
/// than a load.
class _TabFadeIn extends HookWidget {
  const _TabFadeIn({required this.index, required this.child});

  final int index;
  final Widget child;

  /// Opacity the incoming tab starts at. High enough that the swap never looks
  /// like a blank frame.
  static const double _from = 0.55;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);

    final controller = useAnimationController(
      duration: AppDurations.stateChange,
      initialValue: 1,
    );

    // Restarts only when the tab actually changes, never on a rebuild.
    useEffect(() {
      if (animate) controller.forward(from: 0);
      return null;
    }, [index]);

    final t = Curves.easeOut.transform(useAnimation(controller));

    return RepaintBoundary(
      child: Opacity(opacity: _from + (1 - _from) * t, child: child),
    );
  }
}

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              gradient: RadialGradient(
                center: const AlignmentDirectional(-0.7, -0.85),
                radius: 1.35,
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: context.isDark ? 0.16 : 0.10),
                    base,
                  ),
                  base,
                ],
                stops: const [0, 0.75],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _railBreakpoint = 900;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  /// Clock of the last Home-tab back press that we swallowed. A second press
  /// inside [_exitWindow] is what actually leaves the app.
  DateTime? _homeBackAt;

  static const _exitWindow = Duration(seconds: 2);

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context.l10n);
    final hasAlerts = ref.watch(hasCriticalAlertsProvider);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppShellScaffold._railBreakpoint;

    final accent = destinations[_shell.currentIndex].color;

    if (isWide) {
      return _guardBack(
        Scaffold(
          // Same reasoning as the compact shell below: one resize, and it
          // belongs to the screen that owns the text field.
          resizeToAvoidBottomInset: false,
          body: AmbientBackdrop(
            accent: accent,
            child: Row(
              children: [
                RepaintBoundary(
                  child: SideNavRail(
                    destinations: destinations,
                    currentIndex: _shell.currentIndex,
                    badgeIndex: hasAlerts ? 0 : null,
                    onSelected: _go,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: RepaintBoundary(child: _shell),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _guardBack(
      Scaffold(
        extendBody: true,
        // **The shell does not resize for the keyboard; the screen inside it
        // does.** Both Scaffolds default to `resizeToAvoidBottomInset: true`,
        // so an open keyboard was subtracted twice — once here and again in
        // the routed screen — which pushed content up by double the keyboard
        // height and left a band of bare background between the last field and
        // the keys. Holding the shell at full height also keeps the floating
        // navigation bar where it belongs: behind the keyboard, not riding on
        // top of it.
        resizeToAvoidBottomInset: false,
        // **The bar's height reaches the body through `extendBody`, not
        // through a manual `MediaQuery` override.** With `extendBody: true`
        // the Scaffold already publishes
        // `padding.bottom = max(systemInset, bottomNavigationBarHeight)` to the
        // body, and `bottomNavigationBarHeight` is the bar as laid out — its
        // own `SafeArea` and margin included. Injecting the height again on top
        // of that counted the bar twice, which is what left a band of dead
        // space under every scroll view and floated every FAB clear of the bar.
        body: AmbientBackdrop(
          accent: accent,
          child: _TabFadeIn(index: _shell.currentIndex, child: _shell),
        ),
        bottomNavigationBar: RepaintBoundary(
          child: FloatingNavBar(
            destinations: destinations,
            currentIndex: _shell.currentIndex,
            badgeIndex: hasAlerts ? 0 : null,
            onSelected: _go,
          ),
        ),
      ),
    );
  }

  /// System back never pops the shell itself. Nested routes pop first, then
  /// any non-Home tab returns to Home, then Home requires a second press.
  Widget _guardBack(Widget child) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _onSystemBack();
    },
    child: child,
  );

  void _onSystemBack() {
    final index = _shell.currentIndex;
    final nested = _branchNavigatorKeys[index].currentState;
    if (nested != null && nested.canPop()) {
      nested.pop();
      return;
    }

    if (index != 0) {
      _homeBackAt = null;
      _go(0);
      return;
    }

    final now = DateTime.now();
    final last = _homeBackAt;
    if (last != null && now.difference(last) <= _exitWindow) {
      SystemNavigator.pop();
      return;
    }
    _homeBackAt = now;
    showAppSnack(
      context,
      context.l10n.pressBackToExit,
      icon: Icons.logout_rounded,
    );
  }

  /// Tapping a tab always lands on that tab's root view.
  ///
  /// `goBranch(initialLocation: true)` resets the branch's *router* stack, but
  /// it has no visibility of routes pushed imperatively onto the branch
  /// navigator — which is why Home looked dead while Settings was open: the
  /// branch was already index 0, the reset was a no-op, and the imperative
  /// page stayed on top. Clearing the navigator first makes the reset real,
  /// and keeps working for any future imperative push.
  void _go(int index) {
    final navigator = _branchNavigatorKeys[index].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    _shell.goBranch(index, initialLocation: true);
  }

  static List<NavDestination> _destinations(AppLocalizations l10n) => [
    NavDestination(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: l10n.tabHome,
      color: AppColors.cyan,
    ),
    NavDestination(
      icon: Icons.build_circle_outlined,
      activeIcon: Icons.build_circle_rounded,
      label: l10n.tabMaintenanceLog,
      color: AppColors.green,
    ),
    NavDestination(
      icon: Icons.local_gas_station_outlined,
      activeIcon: Icons.local_gas_station_rounded,
      label: l10n.tabFuel,
      color: AppColors.teal,
    ),
    NavDestination(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: l10n.tabExpenses,
      color: AppColors.purple,
    ),
    NavDestination(
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on_rounded,
      label: l10n.tabWorkshops,
      color: AppColors.blue,
    ),
    NavDestination(
      icon: Icons.warning_amber_outlined,
      activeIcon: Icons.warning_amber_rounded,
      label: l10n.emergency,
      color: AppColors.amber,
    ),
  ];
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n.emergency)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: context.screenPadding(top: 4),
            child: const EmergencySection(),
          ),
        ),
      ),
    );
  }
}

class AddFuelScreen extends StatelessWidget {
  const AddFuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const FuelFormSheet(),
          ),
        ),
      ),
    );
  }
}

class DealerDetailsScreen extends ConsumerWidget {
  const DealerDetailsScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dealers = ref.watch(dealersProvider);
    final dealer = dealers.where((d) => d.id == dealerId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(dealer?.name ?? l10n.workshopsAndDealers)),
      body: dealer == null
          ? AppEmptyState(
              icon: Icons.location_off_outlined,
              title: l10n.noDealers,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: context.screenPadding(),
                  child: DealerCard(dealer: dealer),
                ),
              ),
            ),
    );
  }
}

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.somethingWentWrong,
        message: error?.toString(),
        actionLabel: l10n.tabHome,
        onAction: () => GoRouter.of(context).go(AppRoutes.dashboard),
      ),
    );
  }
}
