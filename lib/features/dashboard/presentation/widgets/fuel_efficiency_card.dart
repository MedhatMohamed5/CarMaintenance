import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../../../fuel/domain/entities/fuel_stats.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../fuel/presentation/widgets/fuel_metric_display.dart';

/// Fuel economy in L/100 km — the European standard — against the settled
/// running average, with the open tank amortising in real time underneath.
///
/// The headline is the *live* figure: it includes every kilometre driven since
/// the last fill, so it moves the moment the odometer does. The settled
/// average beside it is the same span truncated at the last fill, which is the
/// stable number worth comparing tanks against.
class FuelEfficiencyCard extends ConsumerWidget {
  const FuelEfficiencyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final stats = ref.watch(fuelStatsProvider);
    final metric = ref.watch(fuelMetricProvider);
    final metrics = ref.watch(vehicleMetricsProvider);

    if (!stats.hasEfficiencyData) {
      return _EmptyFuelCard(openTank: stats.openTank);
    }

    // Lifetime, every figure. Total litres over the tracked distance — never
    // the latest fill, never one tank — so this card, the fuel tab and the
    // analytics grid read from the same numbers.
    final headline = metrics.litersPer100Km;
    final accent = fuelEconomyColor(headline);
    final delta = stats.latestVsAverage;
    final deltaColor = delta >= 0 ? AppColors.green : AppColors.orange;

    return EntranceAnimation(
      delay: const Duration(milliseconds: 140),
      duration: const Duration(milliseconds: 380),
      slide: 0.05,
      child: GlassCard(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.fuelEconomy, style: context.text.titleSmall),
                ),
                const FuelMetricToggle(dense: true),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                AnimatedRingGauge(
                  value: metric.gaugeValue(headline),
                  color: accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        metric.format(headline, locale),
                        style: AppTypography.numeric(context.text.titleLarge),
                      ),
                      Text(
                        metric.unit(l10n),
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                        label: l10n.avgEfficiency,
                        value: metric.format(metrics.litersPer100Km, locale),
                        unit: metric.unit(l10n),
                      ),
                      const SizedBox(height: 10),
                      _Row(
                        label: l10n.bestEfficiency,
                        // The best-performing *grade* over its whole
                        // history, not the single best tank.
                        value: metric.format(
                          metrics.bestLitersPer100Km,
                          locale,
                        ),
                        unit: metric.unit(l10n),
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 10),
                      _Row(
                        // Lifetime cumulative, always two decimals: an integer
                        // would round 2.82 to 3 and lose the difference the
                        // metric exists to show, and a dash would read as a
                        // failure rather than as "nothing driven yet".
                        label: l10n.costPerKm,
                        value: Fmt.dec2(metrics.fuelCostPerKm, locale),
                        unit: '${l10n.currency}/${l10n.km}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stats.openTank != null) ...[
              const SizedBox(height: 14),
              _CurrentTankStrip(tank: stats.openTank!),
            ],
            if (stats.segments.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    delta >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                    color: deltaColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${(delta.abs() * 100).toStringAsFixed(1)}% '
                      '${delta >= 0 ? l10n.raw('better') : l10n.raw('worse')} '
                      '${l10n.raw('vsAverage')}',
                      style: context.text.labelSmall?.copyWith(
                        color: deltaColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live readout for the tank currently in the car.
///
/// Both figures move with the master odometer and neither needs a fuel entry:
/// the distance grows, so the cost per kilometre falls.
class _CurrentTankStrip extends ConsumerWidget {
  const _CurrentTankStrip({required this.tank});

  final OpenTank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, size: 18, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentTank,
                  style: context.text.labelSmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${Fmt.int0(tank.distanceKm, locale)} ${l10n.km} '
                  '${l10n.raw('sinceLastFill')}',
                  style: context.text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatValue(
                value: tank.hasDistance
                    ? Fmt.dec2(tank.costPerKm, locale)
                    : '—',
                unit: l10n.currency,
                style: context.text.titleSmall,
              ),
              Text(
                l10n.runningCostPerKm,
                style: context.text.labelSmall?.copyWith(
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown before a second fill closes the first interval. The tank in the car
/// is still measurable, so the running cost appears immediately.
class _EmptyFuelCard extends ConsumerWidget {
  const _EmptyFuelCard({required this.openTank});

  final OpenTank? openTank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tank = openTank;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccentIconBadge(
                icon: Icons.local_gas_station_rounded,
                color: AppColors.cyan,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.fuelEconomy, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      l10n.needsTwoFills,
                      style: context.text.bodySmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tank != null && tank.hasDistance) ...[
            const SizedBox(height: 12),
            _CurrentTankStrip(tank: tank),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        StatValue(
          value: value,
          unit: unit,
          color: color,
          style: context.text.titleSmall,
        ),
      ],
    );
  }
}
