import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_metric.dart';
import '../../domain/entities/fuel_stats.dart';
import '../providers/fuel_providers.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../widgets/eco_driving_tips_card.dart';
import '../widgets/fuel_metric_display.dart';
import 'fuel_form_sheet.dart';
import '../../../../core/widgets/app_sheet.dart';

/// Tab 4. Fill history with the efficiency each one measured, plus the octane
/// comparison that answers "is 95 actually worth it for my car?".
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = ref.watch(fuelLogsProvider);
    final stats = ref.watch(fuelStatsProvider);

    // Instant metrics per closing fill, so a row can show its own figure.
    final segmentByLogId = ref.watch(fuelSegmentsByLogProvider);
    // Lifetime figures, shared with Home and the analytics grid.
    final metrics = ref.watch(vehicleMetricsProvider);
    final padding = context.splitScreenPadding(hasFab: true);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.fuelLogs)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => FuelFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.add),
        backgroundColor: AppColors.cyan,
        foregroundColor: context.colors.onPrimary,
      ),
      body: logs.isEmpty
          ? AppEmptyState(
              icon: AppIcons.fuel,
              title: l10n.noFuelLogs,
              message: l10n.raw('addFirstEntry'),
              actionLabel: l10n.addFuelEntry,
              onAction: () => FuelFormSheet.show(context),
            )
          // Sliver split rather than one eager `ListView`: the header cards
          // build once, and the history builds lazily so a 400-fill log costs
          // the same per frame as a 10-fill one.
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.header,
                  sliver: SliverList.list(
                    children: [
                      _FuelSummaryStrip(stats: stats),
                      if (stats.openTank != null) ...[
                        const SizedBox(height: 20),
                        _CurrentTankCard(tank: stats.openTank!),
                      ],
                      if (metrics.byFuelType.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const _OctaneComparisonCard(),
                      ],
                      if (stats.segments.length > 1) ...[
                        const SizedBox(height: 20),
                        _EfficiencyTrendCard(stats: stats),
                      ],
                      const SizedBox(height: 20),
                      const EcoDrivingTipsCard(),
                      const SizedBox(height: 20),
                      SectionHeader(title: l10n.fuelLogs, icon: AppIcons.fuel),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: padding.list,
                  sliver: SliverList.builder(
                    itemCount: logs.length,
                    // Keyed on the log id, not the slot: the element, and with
                    // it the "already played" flag, travels with the row, so
                    // inserting or deleting never replays a neighbour's fade.
                    findChildIndexCallback: (key) => indexOfChildKey(
                      key,
                      logs.length,
                      (i) => 'fuel-${logs[i].id}',
                    ),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntranceAnimation.item(
                        key: ValueKey('fuel-${logs[i].id}'),
                        index: i,
                        child: _FuelLogTile(
                          log: logs[i],
                          segment: segmentByLogId[logs[i].id],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FuelSummaryStrip extends ConsumerWidget {
  const _FuelSummaryStrip({required this.stats});

  final FuelStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    // One source for every screen: accumulative over the tracked distance,
    // never scoped to the latest fill.
    final metrics = ref.watch(vehicleMetricsProvider);

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: l10n.fuelEconomy,
            value: metric.format(metrics.litersPer100Km, locale),
            unit: metric.unit(l10n),
            color: fuelEconomyColor(metrics.litersPer100Km),
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            // Lifetime cumulative: total fuel spend over every kilometre
            // since the vehicle's initial reading, amortising on each odometer
            // bump. Always two decimals — the engine guarantees a finite,
            // non-negative double, so `0.00` is the empty state, never a blank
            // or a dash that leaves the tile looking broken.
            label: l10n.costPerKm,
            value: Fmt.dec2(metrics.fuelCostPerKm, locale),
            unit: l10n.currency,
            color: AppColors.green,
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: l10n.totalCost,
            value: Fmt.moneyCompact(metrics.fuelCost, locale),
            unit: l10n.currency,
            color: AppColors.purple,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          StatValue(value: value, unit: unit, style: context.text.titleMedium),
          const SizedBox(height: 2),
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

/// Side-by-side efficiency and cost for each grade the driver has actually
/// used. Bars are scaled to the best performer so the gap is visible even when
/// the absolute numbers are close.
class _OctaneComparisonCard extends ConsumerWidget {
  const _OctaneComparisonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    // Same provider as the header cards: lifetime litres and spend per grade
    // over each grade's share of the tracked distance.
    final grades = ref.watch(vehicleMetricsProvider).byFuelType;
    // Ranked on efficiency so the fullest bar is always the best grade,
    // whichever unit the numbers are printed in.
    final best = grades
        .map((t) => t.avgEfficiency)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.octaneComparison, style: context.text.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.octaneComparisonHint,
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < grades.length; i++) ...[
            _OctaneRow(
              stats: grades[i],
              best: best,
              index: i,
              locale: locale,
              metric: metric,
            ),
            if (i < grades.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _OctaneRow extends StatelessWidget {
  const _OctaneRow({
    required this.stats,
    required this.best,
    required this.index,
    required this.locale,
    required this.metric,
  });

  final FuelTypeStats stats;
  final double best;
  final int index;
  final String locale;
  final FuelMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = FuelTypeStyle.color(stats.fuelType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PillChip(
              label: l10n.raw(stats.fuelType.l10nKey),
              color: color,
              icon: FuelTypeStyle.icon(stats.fuelType),
              selected: true,
              dense: true,
            ),
            const Spacer(),
            StatValue(
              value: metric.format(stats.avgLitersPer100Km, locale),
              unit: metric.unit(l10n),
              color: color,
              style: context.text.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedProgressBar(
          value: best <= 0 ? 0 : (stats.avgEfficiency / best).clamp(0.0, 1.0),
          color: color,
          delay: Duration(milliseconds: 80 * index),
        ),
        const SizedBox(height: 6),
        // Cumulative per grade: everything ever spent on it, over every
        // kilometre it has powered — including the open stretch when this is
        // the grade currently in the tank.
        Row(
          children: [
            Expanded(
              child: Text(
                '${Fmt.money(stats.totalCost, locale)} ${l10n.currency} · '
                '${Fmt.dec2(stats.avgCostPerKm, locale)} '
                '${l10n.currency}/${l10n.km}',
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${Fmt.int0(stats.totalDistanceKm, locale)} ${l10n.km}',
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The tank currently in the car, measured against the live odometer.
///
/// Nothing here waits for the next fill: the numerator was fixed when the fuel
/// was paid for, and every kilometre the master odometer gains stretches the
/// denominator, so the running cost amortises downward in real time.
class _CurrentTankCard extends ConsumerWidget {
  const _CurrentTankCard({required this.tank});

  final OpenTank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    final color = FuelTypeStyle.color(tank.fuelType);

    return GlassCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(
                icon: Icons.speed_rounded,
                color: color,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.currentTank, style: context.text.titleSmall),
                    const SizedBox(height: 1),
                    Text(
                      '${l10n.sinceLastFill} · '
                      '${Fmt.int0(tank.startOdometer, locale)} ${l10n.km}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PillChip(label: l10n.raw('amortising'), dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: l10n.distance,
                value: Fmt.int0(tank.distanceKm, locale),
                unit: l10n.km,
                color: color,
              ),
              _Divider(),
              _Metric(
                label: l10n.runningCostPerKm,
                value: tank.hasDistance
                    ? Fmt.dec2(tank.costPerKm, locale)
                    : '—',
                unit: l10n.currency,
              ),
              _Divider(),
              _Metric(
                label: l10n.raw('onThisTank'),
                value: tank.hasDistance
                    ? metric.format(tank.litersPer100Km, locale)
                    : '—',
                unit: metric.unit(l10n),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sparkline-style history of measured efficiency, oldest to newest.
class _EfficiencyTrendCard extends ConsumerWidget {
  const _EfficiencyTrendCard({required this.stats});

  final FuelStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    final metric = ref.watch(fuelMetricProvider);

    // Oldest first for a left-to-right reading of time. Bars are always sized
    // on efficiency, so a taller bar means a better tank in either unit.
    final points = stats.segments.reversed.toList();
    final max = points
        .map((s) => s.efficiency)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.fuelTrend, style: context.text.titleSmall),
              ),
              const FuelMetricToggle(dense: true),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _TrendBar(
                        height: max <= 0 ? 0 : points[i].efficiency / max,
                        color: FuelTypeStyle.color(points[i].fuelType),
                        index: i,
                        label: metric.format(points[i].litersPer100Km, locale),
                        showLabel: points.length <= 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.height,
    required this.color,
    required this.index,
    required this.label,
    required this.showLabel,
  });

  final double height;
  final Color color;
  final int index;
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLabel)
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              fontSize: 9,
              color: context.tokens.textSecondary,
            ),
          ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: height.clamp(0.06, 1.0)),
          duration: Duration(milliseconds: 600 + index * 60),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Container(
            height: 84 * t,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [color.withValues(alpha: 0.45), color],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FuelLogTile extends ConsumerWidget {
  const _FuelLogTile({required this.log, this.segment});

  final FuelLog log;
  final FuelSegment? segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final color = FuelTypeStyle.color(log.fuelType);

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => _confirmDelete(context, l10n),
      onDismissed: (_) =>
          ref.read(fuelControllerProvider.notifier).remove(log.id),
      child: GlassCard(
        // List row: opaque surface, no backdrop blur to pay for.
        blur: false,
        accent: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: () => FuelFormSheet.show(context, existing: log),
        child: Column(
          children: [
            Row(
              children: [
                AccentIconBadge(
                  icon: FuelTypeStyle.icon(log.fuelType),
                  color: color,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.raw(log.fuelType.l10nKey),
                            style: context.text.titleSmall,
                          ),
                          if (!log.isFullTank) ...[
                            const SizedBox(width: 6),
                            PillChip(
                              label: l10n.raw('partialFill'),
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.date(log.date, locale)} · '
                        '${Fmt.int0(log.odometer, locale)} ${l10n.km}',
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatValue(
                      value: Fmt.money(log.totalCost, locale),
                      unit: l10n.currency,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      '${Fmt.dec1(log.liters, locale)} ${l10n.raw(log.fuelType.volumeUnitKey)} · '
                      '${Fmt.dec2(log.pricePerLiter, locale)}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (segment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _Metric(
                      label: l10n.efficiency,
                      value: ref
                          .watch(fuelMetricProvider)
                          .format(segment!.litersPer100Km, locale),
                      unit: ref.watch(fuelMetricProvider).unit(l10n),
                      color: color,
                    ),
                    _Divider(),
                    _Metric(
                      label: l10n.costPerKm,
                      value: Fmt.dec2(segment!.costPerKm, locale),
                      unit: l10n.currency,
                    ),
                    _Divider(),
                    _Metric(
                      label: l10n.distance,
                      value: Fmt.int0(segment!.distanceKm, locale),
                      unit: l10n.km,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final result = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          StatValue(
            value: value,
            unit: unit,
            color: color,
            style: context.text.titleSmall,
            animate: false,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              fontSize: 9.5,
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: context.tokens.border);
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 24),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: AppColors.red),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.text.labelLarge?.copyWith(color: AppColors.red),
          ),
        ],
      ),
    );
  }
}
