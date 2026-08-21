import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';

/// Efficiency gauge: the latest measured km/L against the running average,
/// with the delta called out so the driver knows whether this tank was good.
class FuelEfficiencyCard extends ConsumerWidget {
  const FuelEfficiencyCard({super.key});

  /// The gauge is normalised against a generous ceiling rather than the
  /// personal best, so the needle position stays comparable over time.
  static const double _gaugeCeiling = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final stats = ref.watch(fuelStatsProvider);

    if (!stats.hasEfficiencyData) {
      return GlassCard(
        child: Row(
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
                  Text(l10n.fuelEfficiency, style: context.text.titleSmall),
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
      );
    }

    final delta = stats.latestVsAverage;
    final deltaColor = delta >= 0 ? AppColors.green : AppColors.orange;

    return GlassCard(
      accent: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.fuelEfficiency, style: context.text.titleSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              AnimatedRingGauge(
                value: stats.latestEfficiency / _gaugeCeiling,
                color: AppColors.cyan,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Fmt.dec1(stats.latestEfficiency, locale),
                      style: AppTypography.numeric(context.text.titleLarge),
                    ),
                    Text(
                      l10n.kmPerLiter,
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
                      value: Fmt.dec1(stats.avgEfficiency, locale),
                      unit: l10n.kmPerLiter,
                    ),
                    const SizedBox(height: 10),
                    _Row(
                      label: l10n.bestEfficiency,
                      value: Fmt.dec1(stats.bestEfficiency, locale),
                      unit: l10n.kmPerLiter,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 10),
                    _Row(
                      label: l10n.costPerKm,
                      value: Fmt.dec2(stats.avgCostPerKm, locale),
                      unit: l10n.currency,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.segments.length > 1) ...[
            const SizedBox(height: 14),
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
                Text(
                  '${(delta.abs() * 100).toStringAsFixed(1)}% '
                  '${delta >= 0 ? l10n.raw('better') : l10n.raw('worse')} '
                  '${l10n.raw('vsAverage')}',
                  style: context.text.labelSmall?.copyWith(color: deltaColor),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 140.ms, duration: 380.ms).slideY(begin: 0.05);
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
