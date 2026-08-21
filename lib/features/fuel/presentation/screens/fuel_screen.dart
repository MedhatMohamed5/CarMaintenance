import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_stats.dart';
import '../providers/fuel_providers.dart';
import 'fuel_form_sheet.dart';

/// Tab 4. Fill history with the efficiency each one measured, plus the octane
/// comparison that answers "is 95 actually worth it for my car?".
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = ref.watch(fuelLogsProvider);
    final stats = ref.watch(fuelStatsProvider);

    // Efficiency measured per closing fill, so a row can show its own figure.
    final segmentByLogId = {
      for (final s in stats.segments) s.log.id: s,
    };

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
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                80 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _FuelSummaryStrip(stats: stats),
                if (stats.byFuelType.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _OctaneComparisonCard(stats: stats),
                ],
                if (stats.segments.length > 1) ...[
                  const SizedBox(height: 20),
                  _EfficiencyTrendCard(stats: stats),
                ],
                const SizedBox(height: 20),
                SectionHeader(title: l10n.fuelLogs, icon: AppIcons.fuel),
                for (var i = 0; i < logs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:
                        _FuelLogTile(
                              log: logs[i],
                              segment: segmentByLogId[logs[i].id],
                            )
                            .animate()
                            .fadeIn(
                              delay: (40 * (i.clamp(0, 8))).ms,
                              duration: 300.ms,
                            )
                            .slideY(begin: 0.04),
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

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: l10n.avgEfficiency,
            value: stats.hasEfficiencyData
                ? Fmt.dec1(stats.avgEfficiency, locale)
                : '—',
            unit: l10n.kmPerLiter,
            color: AppColors.cyan,
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: l10n.costPerKm,
            value: stats.hasEfficiencyData
                ? Fmt.dec2(stats.avgCostPerKm, locale)
                : '—',
            unit: l10n.currency,
            color: AppColors.green,
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: l10n.totalCost,
            value: Fmt.moneyCompact(stats.totalCost, locale),
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
  const _OctaneComparisonCard({required this.stats});

  final FuelStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final best = stats.byFuelType
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
          for (var i = 0; i < stats.byFuelType.length; i++) ...[
            _OctaneRow(
              stats: stats.byFuelType[i],
              best: best,
              index: i,
              locale: locale,
            ),
            if (i < stats.byFuelType.length - 1) const SizedBox(height: 16),
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
  });

  final FuelTypeStats stats;
  final double best;
  final int index;
  final String locale;

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
              value: Fmt.dec1(stats.avgEfficiency, locale),
              unit: l10n.kmPerLiter,
              color: color,
              style: context.text.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedProgressBar(
          value: best <= 0 ? 0 : stats.avgEfficiency / best,
          color: color,
          delay: Duration(milliseconds: 80 * index),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.costPerKm}: ${Fmt.dec2(stats.avgCostPerKm, locale)} '
                '${l10n.currency}',
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ),
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

/// Sparkline-style history of measured efficiency, oldest to newest.
class _EfficiencyTrendCard extends ConsumerWidget {
  const _EfficiencyTrendCard({required this.stats});

  final FuelStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    // Oldest first for a left-to-right reading of time.
    final points = stats.segments.reversed.toList();
    final max = points
        .map((s) => s.efficiency)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.fuelTrend, style: context.text.titleSmall),
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
                        label: Fmt.dec1(points[i].efficiency, locale),
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
                      '${Fmt.dec1(log.liters, locale)} ${l10n.liter} · '
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
                      value: Fmt.dec1(segment!.efficiency, locale),
                      unit: l10n.kmPerLiter,
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

  Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
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
