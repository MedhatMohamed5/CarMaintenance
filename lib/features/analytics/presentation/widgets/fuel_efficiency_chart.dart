import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../fuel/presentation/widgets/fuel_metric_display.dart';
import '../providers/analytics_providers.dart';
import '../providers/vehicle_metrics_provider.dart';

class FuelEfficiencyChart extends ConsumerWidget {
  const FuelEfficiencyChart({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final points = ref.watch(fuelEfficiencyTrendProvider);
    final metric = ref.watch(fuelMetricProvider);
    // The reference line is the lifetime figure, the same one the cards show —
    // not a segment average that would disagree with them.
    final average = ref.watch(vehicleMetricsProvider).litersPer100Km;

    if (points.length < 2) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.fuelTrend, style: context.text.titleSmall),
            const SizedBox(height: 10),
            Text(
              l10n.needsTwoFills,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final values = points.map((p) => p.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.25).clamp(0.5, 5.0);
    final interval = ((maxY - minY + padding * 2) / 4).clamp(0.5, 100.0);

    return GlassCard(
      accent: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.fuelTrend, style: context.text.titleSmall),
              ),
              StatValue(
                value: Fmt.dec1(average, locale),
                unit: l10n.kmPerLiter,
                color: AppColors.cyan,
                style: context.text.titleSmall,
                animate: false,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.tokens.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        child: Text(
                          Fmt.dec1(value, locale),
                          style: context.text.labelSmall?.copyWith(
                            fontSize: 9,
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: (points.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            Fmt.monthShort(points[index].date, locale),
                            style: context.text.labelSmall?.copyWith(
                              fontSize: 9,
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: average,
                      color: AppColors.green.withValues(alpha: 0.6),
                      strokeWidth: 1.5,
                      dashArray: const [6, 4],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => context.tokens.surfaceHigh,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipItems: (spots) => spots.map((spot) {
                      final point = points[spot.spotIndex];
                      return LineTooltipItem(
                        '${Fmt.dec1(point.y, locale)} ${l10n.kmPerLiter}\n',
                        context.text.labelMedium!.copyWith(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${l10n.raw(point.label)}\n'
                                '${Fmt.date(point.date, locale)}',
                            style: context.text.labelSmall?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (final p in points) FlSpot(p.x, p.y)],
                    isCurved: true,
                    curveSmoothness: 0.28,
                    preventCurveOverShooting: true,
                    barWidth: 3,
                    color: AppColors.cyan,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: Color(
                              points[index].colorValue ??
                                  AppColors.cyan.toARGB32(),
                            ),
                            strokeWidth: 2,
                            strokeColor: context.colors.surface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.cyan.withValues(alpha: 0.28),
                          AppColors.cyan.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 14,
                height: 2,
                color: AppColors.green.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.avgEfficiency} · ${metric.format(average, locale)} '
                '${metric.unit(l10n)}',
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
