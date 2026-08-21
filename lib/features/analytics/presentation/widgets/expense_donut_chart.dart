import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/analytics_providers.dart';

class ExpenseDonutChart extends ConsumerStatefulWidget {
  const ExpenseDonutChart({super.key, this.size = 200});

  final double size;

  @override
  ConsumerState<ExpenseDonutChart> createState() => _ExpenseDonutChartState();
}

class _ExpenseDonutChartState extends ConsumerState<ExpenseDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final slices = ref.watch(expenseDonutProvider);
    final total = ref.watch(analyticsSummaryProvider).totalCost;

    if (slices.isEmpty) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.breakdown, style: context.text.titleSmall),
            const SizedBox(height: 10),
            Text(
              l10n.raw('notEnoughData'),
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final selected = _touchedIndex >= 0 && _touchedIndex < slices.length
        ? slices[_touchedIndex]
        : null;

    return GlassCard(
      accent: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.breakdown, style: context.text.titleSmall),
          const SizedBox(height: 16),
          SizedBox(
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: widget.size * 0.24,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          _touchedIndex =
                              event.isInterestedForInteractions &&
                                  response?.touchedSection != null
                              ? response!.touchedSection!.touchedSectionIndex
                              : -1;
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < slices.length; i++)
                        _section(slices[i], i, i == _touchedIndex),
                    ],
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected == null
                          ? l10n.totalSpend
                          : l10n.raw(selected.labelKey),
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.money(selected?.value ?? total, locale),
                      style: AppTypography.numeric(
                        context.text.titleLarge,
                      ).copyWith(
                        color: selected == null
                            ? context.colors.onSurface
                            : Color(selected.colorValue),
                      ),
                    ),
                    Text(
                      selected == null
                          ? l10n.currency
                          : '${(selected.share * 100).toStringAsFixed(1)}%',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < slices.length; i++)
                PillChip(
                  label:
                      '${l10n.raw(slices[i].labelKey)} · '
                      '${Fmt.money(slices[i].value, locale)}',
                  color: Color(slices[i].colorValue),
                  selected: i == _touchedIndex,
                  dense: true,
                  onTap: () => setState(
                    () => _touchedIndex = i == _touchedIndex ? -1 : i,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(DonutSlice slice, int index, bool active) {
    final radius = widget.size * (active ? 0.24 : 0.20);
    return PieChartSectionData(
      value: slice.value,
      color: Color(slice.colorValue),
      radius: radius,
      showTitle: slice.share >= 0.08,
      title: '${(slice.share * 100).round()}%',
      titlePositionPercentageOffset: 0.58,
      titleStyle: context.text.labelSmall?.copyWith(
        fontSize: active ? 12 : 10,
        fontWeight: FontWeight.w800,
        color: context.colors.surface,
      ),
      borderSide: active
          ? BorderSide(color: context.colors.surface, width: 2)
          : BorderSide.none,
    );
  }
}
