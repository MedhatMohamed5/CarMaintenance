import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_brand_title.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../expenses/presentation/screens/expense_form_sheet.dart';
import '../../../fuel/presentation/screens/fuel_form_sheet.dart';
import '../../../notes/presentation/screens/note_form_sheet.dart';
import '../../../notes/presentation/widgets/vehicle_notes_card.dart';
import '../../../onboarding/presentation/dashboard_tour.dart';
import '../../../parking/presentation/screens/parking_sheet.dart';
import '../../../parking/presentation/widgets/parking_card.dart';
import '../../../maintenance/presentation/screens/service_form_sheet.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../../vehicles/presentation/screens/vehicle_form_sheet.dart';
import '../../../vehicles/presentation/widgets/vehicle_hero_card.dart';
import '../../../vehicles/presentation/widgets/vehicle_image.dart';
import '../widgets/alerts_card.dart';
import '../widgets/documents_card.dart';
import '../widgets/fuel_efficiency_card.dart';
import '../widgets/next_service_card.dart';
import '../widgets/parts_health_card.dart';
import '../widgets/spend_summary_card.dart';
import '../../../analytics/presentation/screens/insights_forecast_screen.dart';

/// Tab 1. Everything that matters about the selected car, ordered by urgency:
/// what is wrong, what it costs, what is coming, what is wearing out.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vehicles = ref.watch(vehiclesProvider);
    final vehicle = ref.watch(selectedVehicleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 16,
        title: const AppBrandTitle(),
        actions: [
          if (vehicle != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 2),
              child: Tooltip(
                message: l10n.switchVehicle,
                child: InkResponse(
                  key: TourKeys.vehicleSwitcher,
                  onTap: () => VehicleSwitcherSheet.show(context),
                  radius: 26,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: VehicleAvatar.of(vehicle, size: 32),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.themeMode,
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .toggle(Theme.of(context).brightness),
            icon: AnimatedSwitcher(
              duration: AppDurations.entrance,
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: 0.6, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                context.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(context.isDark),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.raw('analytics'),
            onPressed: () => context.push(AppRoutes.analytics),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: l10n.raw('forecastTitle'),
            onPressed: () => context.push(AppRoutes.forecast),
            icon: const Icon(Icons.query_stats_rounded),
          ),
          IconButton(
            key: TourKeys.settings,
            tooltip: l10n.settings,
            // Routed, not pushed: an imperative page on the branch
            // navigator is invisible to the shell, and the Home tab could not
            // pop it.
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DashboardTourStarter(
        hasVehicle: vehicle != null,
        child: Builder(
          builder: (context) {
            if (vehicles.isEmpty || vehicle == null) {
              return AppEmptyState(
                icon: AppIcons.vehicle,
                title: l10n.noVehicles,
                message: l10n.noVehiclesHint,
                actionLabel: l10n.addVehicle,
                onAction: () => VehicleFormSheet.show(context),
              );
            }

            // One ladder for the whole dashboard, declared in reading order.
            //
            // The cards used to each carry their own delay, which meant the
            // ordering lived in eight files and nobody could see it. Worse, a
            // card that animates itself animates again wherever else it is
            // placed — which is exactly what made the consumables sheet arrive
            // twice. The entrance is a property of the position, so it lives
            // here.
            //
            // The ladder is deliberately short: 8 cards × 55 ms tops out at
            // 385 ms for the last one, against 580 ms before. Every card is a
            // blurred `GlassCard`, so a long overlapping stagger means many
            // simultaneous `saveLayer`s — the frame drops on first paint were
            // the ladder, not the arithmetic behind it.
            const step = AppDurations.entranceStep;

            return ListView(
              padding: context.screenPadding(),
              // **Why the first scroll janked and later ones did not.** A card
              // below the fold is not built when the screen opens; it is built
              // the moment it enters the viewport — mid-scroll — and a dashboard
              // card is not cheap to build: a ring gauge, a chart, counters that
              // each start a 900 ms tween on mount. Build, layout, first paint
              // and the start of an animation all landed inside one scroll
              // frame. From the second scroll on, `EntranceAnimation`'s
              // keep-alive means the card already exists and there is nothing
              // left to pay.
              //
              // A wider cache extent builds the next few cards before the finger
              // reaches them rather than underneath it. It is a trade, not a free
              // win: those cards are laid out during the opening frames instead,
              // where the entrance ladder is already running and has headroom.
              // Roughly three cards ahead — enough to stay in front of a flick,
              // short of building the whole screen up front.
              cacheExtent: 600,
              children: [
                _DashboardCard(
                  order: 0,
                  step: step,
                  child: KeyedSubtree(
                    key: TourKeys.vehicle,
                    child: VehicleHeroCard(vehicle: vehicle),
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardCard(
                  order: 1,
                  step: step,
                  child: KeyedSubtree(
                    key: TourKeys.quickActions,
                    child: const _QuickActions(),
                  ),
                ),
                const SizedBox(height: 20),
                // Directly under the actions: a car waiting somewhere is the most
                // time-sensitive thing on this screen, and `ParkingCard` renders
                // nothing at all when no spot is saved, so it costs no space the
                // rest of the time.
                const _DashboardCard(
                  order: 2,
                  step: step,
                  child: ParkingCard(),
                ),
                // Same rule as `ParkingCard`: a reminder the driver wrote for
                // themselves, gone from the screen the moment it is checked off.
                const _DashboardCard(
                  order: 3,
                  step: step,
                  child: VehicleNotesCard(),
                ),
                const _DashboardCard(order: 4, step: step, child: AlertsCard()),
                const SizedBox(height: 18),
                const _DashboardCard(
                  order: 5,
                  step: step,
                  // Pace is a dashboard-only stat; the expenses tab omits it.
                  child: SpendSummaryCard(showMonthlyPace: true),
                ),
                const SizedBox(height: 18),
                _DashboardCard(
                  order: 6,
                  step: step,
                  child: KeyedSubtree(
                    key: TourKeys.nextService,
                    child: const NextServiceCard(),
                  ),
                ),
                const SizedBox(height: 18),
                const _DashboardCard(
                  order: 7,
                  step: step,
                  child: ForecastTeaserCard(),
                ),
                const SizedBox(height: 18),
                const _DashboardCard(
                  order: 8,
                  step: step,
                  child: FuelEfficiencyCard(),
                ),
                const SizedBox(height: 18),
                const _DashboardCard(
                  order: 9,
                  step: step,
                  child: PartsHealthCard(),
                ),
                const SizedBox(height: 18),
                _DashboardCard(
                  order: 10,
                  step: step,
                  child: DocumentsCard(vehicle: vehicle),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One rung of the dashboard's entrance ladder.
///
/// Keyed on its position so the played state belongs to the slot: rebuilding
/// the list — a vehicle switch, a provider emission — reuses the same elements
/// and nothing re-animates.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.order,
    required this.step,
    required this.child,
  });

  final int order;
  final Duration step;
  final Widget child;

  @override
  Widget build(BuildContext context) => EntranceAnimation(
    key: ValueKey('dashboard-card-$order'),
    delay: step * order,
    duration: AppDurations.entranceItem,
    child: child,
  );
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final actions = <_QuickAction>[
      _QuickAction(
        icon: AppIcons.fuel,
        title: l10n.tabFuel,
        subtitle: l10n.addFuelEntry,
        color: AppColors.cyan,
        onTap: () => FuelFormSheet.show(context),
      ),
      _QuickAction(
        icon: AppIcons.serviceLog,
        title: l10n.maintenance,
        subtitle: l10n.logService,
        color: AppColors.green,
        onTap: () => ServiceFormSheet.show(context),
      ),
      _QuickAction(
        icon: AppIcons.expenses,
        title: l10n.expenses,
        subtitle: l10n.addExpense,
        color: AppColors.purple,
        onTap: () => ExpenseFormSheet.show(context),
      ),
      _QuickAction(
        icon: Icons.local_parking_rounded,
        title: l10n.raw('parkingTitle'),
        subtitle: l10n.raw('parkingSave'),
        color: AppColors.teal,
        onTap: () => ParkingSheet.show(context),
      ),
      _QuickAction(
        icon: Icons.checklist_rounded,
        title: l10n.notes,
        subtitle: l10n.raw('addNote'),
        color: AppColors.amber,
        onTap: () => NoteFormSheet.show(context),
      ),
    ];

    // Entrance supplied by the ladder in `_DashboardCard`.
    //
    // **A grid sized by width, not a single row sized by count.** Four actions
    // abreast left each tile about 74 pt on a phone — narrower than the badge
    // and its affordance together, which is what overflowed the row. Wrapping
    // to two columns gives each tile roughly 159 pt: the icon has room, the
    // labels stop shrinking to fit, and a fifth action costs a row rather than
    // squeezing the four that already exist. A tablet still gets them in one
    // line, because there the width is genuinely there.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _minTileWidth).floor().clamp(
          2,
          4,
        );
        final rows = (actions.length + columns - 1) ~/ columns;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: _gap),
              SizedBox(
                height: _tileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: _gap),
                      Expanded(child: _tileAt(actions, row * columns + column)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// The tile at [index], or empty space holding the column open.
  ///
  /// A last row that does not divide evenly keeps its remaining columns rather
  /// than letting the tiles that are there stretch to fill the gap — five
  /// actions should read as five equal tiles and one space, not as four normal
  /// ones and a wide outlier.
  static Widget _tileAt(List<_QuickAction> actions, int index) =>
      index < actions.length
      ? _ActionTile(action: actions[index])
      : const SizedBox.shrink();

  /// Below this the badge and its `+` stop fitting side by side.
  static const double _minTileWidth = 150;
  static const double _gap = 10;
  static const double _tileHeight = 104;
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _QuickAction action;

  static const double _badgeSize = 38;
  static const double _addSize = 20;

  @override
  Widget build(BuildContext context) {
    final color = action.color;

    return GlassCard(
      accent: color,
      elevated: true,
      onTap: action.onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **Sized against the space actually available, not a fixed count.**
          // The badge and the `+` bubble together need a fixed 58 pt, which
          // four tiles in a row on a narrow phone cannot give — adding the
          // parking action was enough to overflow the row. Measuring instead of
          // assuming means the tile degrades on its own: it drops the affordance
          // first, then shrinks the badge, and a fifth action or a smaller phone
          // costs nothing to support.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final showAdd = width >= _badgeSize + _addSize + 6;
              final badge = showAdd
                  ? _badgeSize
                  : width.clamp(22.0, _badgeSize).toDouble();

              return Row(
                children: [
                  AccentIconBadge(icon: action.icon, color: color, size: badge),
                  if (showAdd) ...[
                    const Spacer(),
                    Container(
                      width: _addSize,
                      height: _addSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                      ),
                      child: Icon(Icons.add_rounded, size: 13, color: color),
                    ),
                  ],
                ],
              );
            },
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              action.title,
              maxLines: 1,
              style: context.text.titleSmall,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              action.subtitle,
              maxLines: 1,
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
