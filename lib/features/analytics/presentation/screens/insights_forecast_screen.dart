import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../fuel/presentation/screens/fuel_form_sheet.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/vehicle_forecast.dart';
import '../providers/forecast_providers.dart';

class InsightsForecastScreen extends ConsumerWidget {
  const InsightsForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicle = ref.watch(selectedVehicleProvider);
    final forecast = ref.watch(vehicleForecastProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.raw('forecastTitle'))),
      body: vehicle == null
          ? AppEmptyState(
              icon: Icons.query_stats_rounded,
              title: l10n.noVehicles,
              message: l10n.noVehiclesHint,
            )
          : ListView(
              padding: context.screenPadding(),
              children: [
                if (!forecast.hasEnoughData)
                  AppEmptyState(
                    icon: Icons.speed_rounded,
                    title: l10n.raw('forecastNeedDataTitle'),
                    message: l10n.raw('forecastNeedDataHint'),
                    actionLabel: l10n.addFuelEntry,
                    onAction: () => FuelFormSheet.show(context),
                  )
                else ...[
                  EntranceAnimation(
                    delay: AppDurations.entranceStep,
                    child: _HabitsCard(forecast: forecast, locale: locale),
                  ),
                  const SizedBox(height: 18),
                  EntranceAnimation(
                    delay: AppDurations.entranceStep * 2,
                    child: _DatesCard(forecast: forecast, locale: locale),
                  ),
                  const SizedBox(height: 18),
                  EntranceAnimation(
                    delay: AppDurations.entranceStep * 3,
                    child: _SpendCard(forecast: forecast, locale: locale),
                  ),
                  const SizedBox(height: 18),
                  EntranceAnimation(
                    delay: AppDurations.entranceStep * 4,
                    child: _GaugesCard(forecast: forecast, locale: locale),
                  ),
                ],
              ],
            ),
    );
  }
}

class ForecastTeaserCard extends ConsumerWidget {
  const ForecastTeaserCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicle = ref.watch(selectedVehicleProvider);
    if (vehicle == null) return const SizedBox.shrink();

    final forecast = ref.watch(vehicleForecastProvider);
    final next = forecast.services.isEmpty ? null : forecast.services.first;

    return EntranceAnimation(
      delay: AppDurations.entranceStep * 3,
      duration: AppDurations.entrance,
      slide: 0.05,
      child: GlassCard(
        accent: AppColors.indigo,
        elevated: true,
        onTap: () => context.push(AppRoutes.forecast),
        child: Row(
          children: [
            const AccentIconBadge(
              icon: Icons.query_stats_rounded,
              color: AppColors.indigo,
              size: 44,
              filled: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.raw('forecastTitle'),
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    forecast.hasEnoughData
                        ? '${Fmt.dec1(forecast.avgDailyKm, locale)} '
                              '${l10n.km} / ${l10n.raw('forecastPerDay')}'
                              '${next?.projectedDate == null ? '' : ' · ${Fmt.date(next!.projectedDate!, locale)}'}'
                        : l10n.raw('forecastNeedDataHint'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.forecast, required this.locale});

  final VehicleForecast forecast;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('forecastHabits'),
          icon: AppIcons.odometer,
        ),
        GlassCard(
          accent: AppColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricRow(
                icon: Icons.route_rounded,
                color: AppColors.cyan,
                label: l10n.raw('forecastAvgDaily'),
                value: Fmt.dec1(forecast.avgDailyKm, locale),
                unit: '${l10n.km} / ${l10n.raw('forecastPerDay')}',
              ),
              const SizedBox(height: 14),
              _MetricRow(
                icon: Icons.calendar_view_month_rounded,
                color: AppColors.teal,
                label: l10n.raw('forecastMonthlyKm'),
                value: Fmt.int0(forecast.projectedMonthlyKm, locale),
                unit: l10n.km,
              ),
              const SizedBox(height: 14),
              _MetricRow(
                icon: Icons.calendar_month_rounded,
                color: AppColors.indigo,
                label: l10n.raw('forecastYearlyKm'),
                value: Fmt.int0(forecast.projectedYearlyKm, locale),
                unit: l10n.km,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DatesCard extends StatelessWidget {
  const _DatesCard({required this.forecast, required this.locale});

  final VehicleForecast forecast;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      ...forecast.services,
      ...forecast.parts.where((p) => p.isOverdue || p.remainingKm <= 2000),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('forecastDates'),
          icon: AppIcons.calendar,
        ),
        GlassCard(
          accent: AppColors.amber,
          child: items.isEmpty
              ? Text(
                  l10n.raw('forecastNoUpcoming'),
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _DateRow(item: items[i], locale: locale),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.item, required this.locale});

  final ForecastItem item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Color(item.colorValue);
    final date = item.projectedDate;
    final kmLabel = item.isOverdue
        ? l10n.overdue
        : '${Fmt.int0(item.remainingKm.abs(), locale)} ${l10n.km}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.isPart ? AppIcons.of(item.iconKey ?? '') : AppIcons.schedule,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.raw(item.l10nKey), style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(
                kmLabel,
                style: context.text.bodySmall?.copyWith(
                  color: item.isOverdue
                      ? AppColors.red
                      : context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          date == null ? '—' : Fmt.date(date, locale),
          style: context.text.labelMedium?.copyWith(
            color: item.isOverdue ? AppColors.red : context.colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.forecast, required this.locale});

  final VehicleForecast forecast;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('forecastSpend'),
          icon: AppIcons.expenses,
        ),
        GlassCard(
          accent: AppColors.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SpendBlock(
                title: l10n.tabFuel,
                color: AppColors.cyan,
                monthly: forecast.monthlyFuelCost,
                yearly: forecast.yearlyFuelCost,
                locale: locale,
                extra:
                    '${Fmt.dec1(forecast.monthlyLiters, locale)} ${l10n.raw('litersShort')} / ${l10n.raw('forecastPerMonth')}',
              ),
              const SizedBox(height: 16),
              _SpendBlock(
                title: l10n.maintenance,
                color: AppColors.amber,
                monthly: forecast.monthlyMaintenanceCost,
                yearly: forecast.yearlyMaintenanceCost,
                locale: locale,
              ),
              const SizedBox(height: 16),
              // Amortised, not projected from distance: a policy costs the same
              // however far the car is driven. See `VehicleForecast`.
              _SpendBlock(
                title: l10n.raw('forecastPolicies'),
                color: AppColors.green,
                monthly: forecast.monthlyPolicyCost,
                yearly: forecast.yearlyPolicyCost,
                locale: locale,
                extra: l10n.raw('forecastPoliciesHint'),
              ),
              const SizedBox(height: 16),
              _SpendBlock(
                title: l10n.raw('forecastTotal'),
                color: AppColors.purple,
                monthly: forecast.monthlyTotalCost,
                yearly: forecast.yearlyTotalCost,
                locale: locale,
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpendBlock extends StatelessWidget {
  const _SpendBlock({
    required this.title,
    required this.color,
    required this.monthly,
    required this.yearly,
    required this.locale,
    this.extra,
    this.emphasized = false,
  });

  final String title;
  final Color color;
  final double monthly;
  final double yearly;
  final String locale;
  final String? extra;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SpendFigure(
                label: l10n.raw('forecastPerMonth'),
                value: Fmt.money(monthly, locale),
                unit: l10n.currency,
                emphasized: emphasized,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SpendFigure(
                label: l10n.raw('forecastPerYear'),
                value: Fmt.money(yearly, locale),
                unit: l10n.currency,
                emphasized: emphasized,
              ),
            ),
          ],
        ),
        if (extra != null) ...[
          const SizedBox(height: 6),
          Text(
            extra!,
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpendFigure extends StatelessWidget {
  const _SpendFigure({
    required this.label,
    required this.value,
    required this.unit,
    required this.emphasized,
  });

  final String label;
  final String value;
  final String unit;
  final bool emphasized;

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
        const SizedBox(height: 2),
        StatValue(
          value: value,
          unit: unit,
          animate: false,
          style: emphasized
              ? context.text.titleMedium
              : context.text.titleSmall,
        ),
      ],
    );
  }
}

class _GaugesCard extends StatelessWidget {
  const _GaugesCard({required this.forecast, required this.locale});

  final VehicleForecast forecast;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = forecast.parts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('forecastGauges'),
          icon: Icons.donut_large_rounded,
        ),
        GlassCard(
          accent: AppColors.green,
          child: parts.isEmpty
              ? Text(
                  l10n.raw('forecastNoParts'),
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < parts.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _GaugeRow(item: parts[i], locale: locale, index: i),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({
    required this.item,
    required this.locale,
    required this.index,
  });

  final ForecastItem item;
  final String locale;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remaining = (item.remainingFraction ?? 0).clamp(0.0, 1.0);
    final color = AppColors.health(remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.of(item.iconKey ?? ''), size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.raw(item.l10nKey),
                style: context.text.titleSmall,
              ),
            ),
            Text(
              '${Fmt.int0(remaining * 100, locale)}%',
              style: context.text.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedProgressBar(
          value: remaining,
          color: color,
          delay:
              AppDurations.entranceStep *
              index.clamp(0, AppDurations.entranceStepCap),
        ),
        const SizedBox(height: 4),
        Text(
          '${Fmt.int0(item.remainingKm, locale)} ${l10n.km} · ${l10n.remaining}',
          style: context.text.bodySmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
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
          animate: false,
          style: context.text.titleSmall,
        ),
      ],
    );
  }
}
