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
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../providers/analytics_providers.dart';

class OdometerTrendChart extends ConsumerWidget {
  const OdometerTrendChart({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final points = ref.watch(odometerTrendProvider);
    final dailyPace = ref.watch(dailyPaceProvider);

    if (points.length < 2) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.currentOdometer, style: context.text.titleSmall),
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

    final values = points.map((p) => p.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range == 0 ? 100.0 : range * 0.12;
    final interval = range == 0 ? 100.0 : (range + padding * 2) / 4;

    return GlassCard(
      accent: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.currentOdometer,
                  style: context.text.titleSmall,
                ),
              ),
              StatValue(
                value: Fmt.int0(dailyPace, locale),
                unit: '${l10n.km}/${l10n.day}',
                color: AppColors.green,
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
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: minY - padding,
                maxY: maxY + padding,
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
                      reservedSize: 46,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        child: Text(
                          Fmt.moneyCompact(value, locale),
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
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (bar, indexes) => indexes
                      .map(
                        (_) => TouchedSpotIndicatorData(
                          FlLine(
                            color: AppColors.green.withValues(alpha: 0.5),
                            strokeWidth: 1.5,
                            dashArray: const [4, 3],
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, b, i) =>
                                FlDotCirclePainter(
                                  radius: 5,
                                  color: AppColors.green,
                                  strokeWidth: 2,
                                  strokeColor: context.colors.surface,
                                ),
                          ),
                        ),
                      )
                      .toList(),
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
                        '${Fmt.int0(point.y, locale)} ${l10n.km}\n',
                        context.text.labelMedium!.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(
                            text: Fmt.date(point.date, locale),
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
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    isStrokeCapRound: true,
                    barWidth: 3,
                    color: AppColors.green,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.green.withValues(alpha: 0.30),
                          AppColors.green.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }
}
