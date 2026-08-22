import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/dealers/presentation/providers/dealer_providers.dart';
import '../../features/dealers/presentation/screens/workshops_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/analytics/presentation/screens/export_report_screen.dart';
import '../../features/dealers/presentation/widgets/dealer_card.dart';
import '../../features/emergency/presentation/widgets/emergency_section.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/fuel/presentation/screens/fuel_form_sheet.dart';
import '../../features/fuel/presentation/screens/fuel_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_log_screen.dart';
import '../../features/maintenance/presentation/screens/service_schedule_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../localization/app_localizations.dart';
import '../utils/screen_insets.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/side_nav_rail.dart';

class AppRoutes {
  const AppRoutes._();

  static const String dashboard = '/';
  static const String maintenance = '/maintenance';
  static const String fuel = '/fuel';
  static const String expenses = '/expenses';
  static const String workshops = '/workshops';
  static const String emergency = '/emergency';

  static const String analytics = '/analytics';
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
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeDashboardScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => const AnalyticsScreen(),
                  ),
                  // Owned by the router, not pushed imperatively: a route the
                  // shell cannot see is a route `goBranch` cannot pop.
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
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
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MaintenanceLogScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'schedule',
                    builder: (context, state) => const ServiceScheduleScreen(),
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
                    const NoTransitionPage(child: FuelScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _expensesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExpensesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _workshopsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.workshops,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: WorkshopsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _emergencyNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.emergency,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: EmergencyScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addFuel,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const ModalPage(
          child: AddFuelScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealerDetails}/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ModalPage(
          child: DealerDetailsScreen(
            dealerId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.exportReport,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const ModalPage(
          child: ExportReportScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => RouteErrorScreen(error: state.error),
  );
});

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
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
      child: child,
    );
  }
}

class ModalPage<T> extends CustomTransitionPage<T> {
  const ModalPage({required super.child, super.key})
    : super(
        transitionsBuilder: _slideUp,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      );

  static Widget _slideUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
    child: FadeTransition(opacity: animation, child: child),
  );
}

class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _railBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _destinations(context.l10n);
    final hasAlerts = ref.watch(hasCriticalAlertsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _railBreakpoint;

    final accent = destinations[navigationShell.currentIndex].color;

    if (isWide) {
      return Scaffold(
        body: AmbientBackdrop(
          accent: accent,
          child: Row(
            children: [
              SideNavRail(
                destinations: destinations,
                currentIndex: navigationShell.currentIndex,
                badgeIndex: hasAlerts ? 0 : null,
                onSelected: _go,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: navigationShell,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: AmbientBackdrop(
        accent: accent,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.paddingOf(context).copyWith(
              bottom: FloatingNavBar.totalHeight(context),
            ),
            viewPadding: MediaQuery.viewPaddingOf(context).copyWith(
              bottom: FloatingNavBar.totalHeight(context),
            ),
          ),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        badgeIndex: hasAlerts ? 0 : null,
        onSelected: _go,
      ),
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
    navigationShell.goBranch(index, initialLocation: true);
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
