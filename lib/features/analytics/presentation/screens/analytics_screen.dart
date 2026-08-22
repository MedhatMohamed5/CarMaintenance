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
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../providers/analytics_providers.dart';
import '../widgets/expense_donut_chart.dart';
import '../widgets/fuel_efficiency_chart.dart';
import '../widgets/odometer_trend_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vehicle = ref.watch(selectedVehicleProvider);
    final hasData = ref.watch(analyticsHasDataProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.raw('analytics')),
        actions: [
          IconButton(
            tooltip: l10n.raw('exportReport'),
            onPressed: vehicle == null
                ? null
                : () => context.push(AppRoutes.exportReport),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: vehicle == null
          ? AppEmptyState(
              icon: Icons.insights_outlined,
              title: l10n.noVehicles,
              message: l10n.noVehiclesHint,
            )
          : ListView(
              padding: context.screenPadding(),
              children: [
                const _RangeSelector(),
                const SizedBox(height: 18),
                if (!hasData)
                  AppEmptyState(
                    icon: Icons.query_stats_rounded,
                    title: l10n.raw('notEnoughData'),
                    message: l10n.raw('addFirstEntry'),
                  )
                else ...[
                  const _SummaryGrid(),
                  const SizedBox(height: 18),
                  const FuelEfficiencyChart(),
                  const SizedBox(height: 18),
                  const ExpenseDonutChart(),
                  const SizedBox(height: 18),
                  const OdometerTrendChart(),
                ],
              ],
            ),
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  static const Map<AnalyticsRange, String> _labels = {
    AnalyticsRange.last3Months: 'rangeLast3Months',
    AnalyticsRange.last6Months: 'rangeLast6Months',
    AnalyticsRange.lastYear: 'rangeLastYear',
    AnalyticsRange.allTime: 'rangeAllTime',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final selected = ref.watch(analyticsRangeProvider);
    final custom = ref.watch(analyticsCustomSpanProvider);
    final span = ref.watch(analyticsSpanProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('dateRange'),
          icon: Icons.date_range_rounded,
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in _labels.entries) ...[
                PillChip(
                  label: l10n.raw(entry.value),
                  selected: custom == null && selected == entry.key,
                  onTap: () =>
                      ref.read(analyticsRangeProvider.notifier).set(entry.key),
                ),
                const SizedBox(width: 8),
              ],
              PillChip(
                label: l10n.raw('customRange'),
                icon: Icons.edit_calendar_rounded,
                selected: custom != null,
                onTap: () => _pickRange(context, ref, span),
              ),
            ],
          ),
        ),
        if (custom != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 14,
                color: context.tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${Fmt.date(custom.start, locale)} — '
                '${Fmt.date(custom.end, locale)}',
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    DateSpan current,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: current.start.isBefore(DateTime(now.year - 20))
            ? DateTime(now.year, now.month - 6, now.day)
            : current.start,
        end: current.end.isAfter(now) ? now : current.end,
      ),
    );
    if (picked == null) return;

    ref.read(analyticsCustomSpanProvider.notifier).state = DateSpan(
      start: DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ),
      end: DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      ),
    );
  }
}

class _SummaryGrid extends ConsumerWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final summary = ref.watch(analyticsSummaryProvider);

    final tiles = <Widget>[
      _SummaryTile(
        icon: Icons.account_balance_wallet_outlined,
        label: l10n.totalSpend,
        value: Fmt.money(summary.totalCost, locale),
        unit: l10n.currency,
        color: AppColors.purple,
      ),
      _SummaryTile(
        icon: Icons.payments_outlined,
        label: l10n.costPerKm,
        value: summary.costPerKm <= 0
            ? '—'
            : Fmt.dec2(summary.costPerKm, locale),
        unit: l10n.currency,
        color: AppColors.green,
      ),
      _SummaryTile(
        icon: Icons.speed_rounded,
        label: l10n.avgEfficiency,
        value: summary.avgEfficiency <= 0
            ? '—'
            : Fmt.dec1(summary.avgEfficiency, locale),
        unit: l10n.kmPerLiter,
        color: AppColors.cyan,
      ),
      _SummaryTile(
        icon: Icons.route_rounded,
        label: l10n.raw('totalDistance'),
        value: Fmt.int0(summary.distanceKm, locale),
        unit: l10n.km,
        color: AppColors.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            for (var i = 0; i < tiles.length; i++)
              tiles[i]
                  .animate()
                  .fadeIn(delay: (60 * i).ms, duration: 320.ms)
                  .slideY(begin: 0.06),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          StatValue(
            value: value,
            unit: unit,
            style: context.text.titleMedium,
            animate: false,
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
