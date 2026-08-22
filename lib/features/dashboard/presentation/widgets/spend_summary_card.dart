import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';

/// What the car has cost so far, split across the four disjoint streams that
/// make up the total, over the distance it has actually been driven.
///
/// Cost per kilometre is the headline the card exists for:
/// `(fuel + service + parts + other) / (currentOdometer - initialOdometer)`.
/// Both halves move on their own — spend when money is logged, distance when
/// the odometer is updated — so the figure falls as the car is driven.
class SpendSummaryCard extends ConsumerWidget {
  const SpendSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final cost = ref.watch(vehicleMetricsProvider);
    final monthly = ref.watch(monthlyPaceProvider);

    return EntranceAnimation(
      delay: const Duration(milliseconds: 80),
      duration: const Duration(milliseconds: 380),
      slide: 0.05,
      child: GlassCard(
        accent: AppColors.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.totalSpend,
              style: context.text.labelMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _AnimatedMoney(
              value: cost.totalSpend,
              locale: locale,
              unit: l10n.currency,
            ),
            const SizedBox(height: 16),
            // Composition bar: one glance shows whether fuel or repairs dominate.
            _CompositionBar(
              segments: [
                (cost.fuelCost, AppColors.cyan),
                (cost.serviceCost, AppColors.amber),
                (cost.partsCost, AppColors.teal),
                (cost.otherCost, AppColors.purple),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LegendDot(
                  color: AppColors.cyan,
                  label: l10n.tabFuel,
                  value: Fmt.money(cost.fuelCost, locale),
                ),
                _LegendDot(
                  color: AppColors.amber,
                  label: l10n.maintenance,
                  value: Fmt.money(cost.serviceCost, locale),
                ),
                // Consumables fitted outside a service. Parts replaced *during*
                // one are already priced into the maintenance figure.
                if (cost.partsCost > 0)
                  _LegendDot(
                    color: AppColors.teal,
                    label: l10n.raw('consumableParts'),
                    value: Fmt.money(cost.partsCost, locale),
                  ),
                _LegendDot(
                  color: AppColors.purple,
                  label: l10n.expenses,
                  value: Fmt.money(cost.otherCost, locale),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: context.tokens.border, height: 1),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: _MiniStat(
                        label: l10n.costPerKm,
                        value: Fmt.dec2(cost.totalCostPerKm, locale),
                        unit: '${l10n.currency}/${l10n.km}',
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: context.tokens.border,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10,
                      ),
                      child: _MiniStat(
                        // The denominator, shown beside the ratio it produced,
                        // with the two readings it came from underneath: a zero
                        // here is almost always a wrong starting reading, and
                        // this makes that visible instead of mysterious.
                        label: l10n.raw('trackedDistance'),
                        value: Fmt.int0(cost.trackedDistanceKm, locale),
                        unit: l10n.km,
                        color: AppColors.cyan,
                        caption:
                            '${Fmt.int0(cost.initialOdometer, locale)}'
                            ' → '
                            '${Fmt.int0(cost.currentOdometer, locale)}',
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: context.tokens.border,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: _MiniStat(
                        label: l10n.avgMonthly,
                        value: monthly <= 0 ? '—' : Fmt.int0(monthly, locale),
                        unit: l10n.km,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!cost.hasDistance) ...[
              const SizedBox(height: 10),
              Text(
                l10n.raw('noDistanceYet'),
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedMoney extends StatelessWidget {
  const _AnimatedMoney({
    required this.value,
    required this.locale,
    required this.unit,
  });

  final double value;
  final String locale;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: StatValue(
          value: Fmt.money(v, locale),
          unit: unit,
          style: context.text.displaySmall,
          animate: false,
        ),
      ),
    );
  }
}

/// Proportional stacked bar. Renders an even split of the track when there is
/// no spend yet, so the card still has structure on day one.
class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.segments});

  final List<(double, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, x) => s + x.$1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 10,
        child: total <= 0
            ? ColoredBox(color: context.tokens.surfaceHigh)
            : Row(
                children: [
                  for (final (amount, color) in segments)
                    if (amount > 0)
                      Expanded(
                        flex: (amount / total * 1000).round().clamp(1, 1000),
                        child: Container(
                          color: color,
                          margin: const EdgeInsetsDirectional.only(end: 2),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  /// Optional second line: the raw inputs behind [value].
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: StatValue(
            value: value,
            unit: unit,
            color: color,
            style: context.text.titleMedium,
            animate: false,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              caption!,
              maxLines: 1,
              style: AppTypography.numeric(
                context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
