import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_brand_title.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../expenses/presentation/screens/expense_form_sheet.dart';
import '../../../fuel/presentation/screens/fuel_form_sheet.dart';
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
              duration: const Duration(milliseconds: 320),
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
      body: Builder(
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

          return ListView(
            padding: context.screenPadding(),
            children: [
              VehicleHeroCard(vehicle: vehicle),
              const SizedBox(height: 18),
              const _QuickActions(),
              const SizedBox(height: 20),
              const AlertsCard(),
              const SizedBox(height: 18),
              const SpendSummaryCard(),
              const SizedBox(height: 18),
              const NextServiceCard(),
              const SizedBox(height: 18),
              const FuelEfficiencyCard(),
              const SizedBox(height: 18),
              const PartsHealthCard(),
              const SizedBox(height: 18),
              DocumentsCard(vehicle: vehicle),
            ],
          );
        },
      ),
    );
  }
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
    ];

    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _ActionTile(action: actions[i])),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 60.ms, duration: 340.ms).slideY(begin: 0.08);
  }
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
          Row(
            children: [
              AccentIconBadge(icon: action.icon, color: color, size: 38),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(Icons.add_rounded, size: 13, color: color),
              ),
            ],
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
