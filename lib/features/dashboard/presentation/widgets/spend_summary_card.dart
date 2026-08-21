import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';

/// What the car has cost so far, split by where the money went, plus the two
/// figures that make the total meaningful: cost per kilometre and monthly pace.
class SpendSummaryCard extends ConsumerWidget {
  const SpendSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final cost = ref.watch(totalCostProvider);
    final perKm = ref.watch(overallCostPerKmProvider);
    final monthly = ref.watch(monthlyPaceProvider);

    return GlassCard(
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
          _AnimatedMoney(value: cost.total, locale: locale, unit: l10n.currency),
          const SizedBox(height: 16),
          // Composition bar: one glance shows whether fuel or repairs dominate.
          _CompositionBar(
            segments: [
              (cost.fuel, AppColors.cyan),
              (cost.service, AppColors.amber),
              (cost.other, AppColors.purple),
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
                value: Fmt.money(cost.fuel, locale),
              ),
              _LegendDot(
                color: AppColors.amber,
                label: l10n.maintenance,
                value: Fmt.money(cost.service, locale),
              ),
              _LegendDot(
                color: AppColors.purple,
                label: l10n.expenses,
                value: Fmt.money(cost.other, locale),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.tokens.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l10n.costPerKm,
                  value: perKm <= 0 ? '—' : Fmt.dec2(perKm, locale),
                  unit: '${l10n.currency}/${l10n.km}',
                  color: AppColors.green,
                ),
              ),
              Container(width: 1, height: 34, color: context.tokens.border),
              Expanded(
                child: _MiniStat(
                  label: l10n.avgMonthly,
                  value: monthly <= 0 ? '—' : Fmt.int0(monthly, locale),
                  unit: l10n.km,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 380.ms).slideY(begin: 0.05);
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
      builder: (context, v, _) => StatValue(
        value: Fmt.money(v, locale),
        unit: unit,
        style: context.text.displaySmall,
        animate: false,
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
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        StatValue(
          value: value,
          unit: unit,
          color: color,
          style: context.text.titleMedium,
        ),
      ],
    );
  }
}
