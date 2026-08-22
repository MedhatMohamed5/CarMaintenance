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
import '../../../analytics/domain/entities/vehicle_metrics.dart';
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

  /// Usable width inside the 118 px ring once the 10 px stroke and its padding
  /// are taken off. Anything wider is scaled down rather than clipped.
  static const double _gaugeLabelWidth = 78;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    final metrics = ref.watch(vehicleMetricsProvider);

    if (!metrics.hasFuelDistance) {
      return const _EmptyFuelCard();
    }

    // Accumulative: every litre ever logged over the whole fuel span. The fuel
    // tab and the analytics grid read the same object, so the three screens
    // cannot show three different numbers.
    final headline = metrics.litersPer100Km;
    final accent = fuelEconomyColor(headline);

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
                  // The ring's inner circle is narrower than the gauge itself,
                  // so a two-decimal figure has to be told how much room it
                  // really has or it clips mid-digit.
                  child: SizedBox(
                    width: _gaugeLabelWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            metric.format(headline, locale),
                            maxLines: 1,
                            style: AppTypography.numeric(
                              context.text.titleLarge,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            metric.unit(l10n),
                            maxLines: 1,
                            style: context.text.labelSmall?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
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
            const SizedBox(height: 14),
            _TotalsStrip(metrics: metrics),
          ],
        ),
      ),
    );
  }
}

/// The two totals the accumulative figures are built from, stated openly so
/// the ratio above is checkable rather than something the card just asserts.
class _TotalsStrip extends ConsumerWidget {
  const _TotalsStrip({required this.metrics});

  final VehicleMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Total(
              label: l10n.raw('trackedDistance'),
              value: Fmt.int0(metrics.fuelDistanceKm, locale),
              unit: l10n.km,
            ),
          ),
          Container(width: 1, height: 26, color: tokens.border),
          Expanded(
            child: _Total(
              label: l10n.fuelAmount,
              value: Fmt.dec1(metrics.totalLiters, locale),
              unit: l10n.liter,
            ),
          ),
          Container(width: 1, height: 26, color: tokens.border),
          Expanded(
            child: _Total(
              label: l10n.totalCost,
              value: Fmt.moneyCompact(metrics.fuelCost, locale),
              unit: l10n.currency,
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: StatValue(
            value: value,
            unit: unit,
            style: context.text.titleSmall,
            animate: false,
          ),
        ),
      ],
    );
  }
}

/// Shown before a second fill closes the first interval. The tank in the car
/// is still measurable, so the running cost appears immediately.
class _EmptyFuelCard extends StatelessWidget {
  const _EmptyFuelCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
