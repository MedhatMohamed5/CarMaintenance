import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/swipe_hint.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_metric.dart';
import '../../domain/entities/fuel_stats.dart';
import '../providers/fuel_providers.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../widgets/eco_driving_tips_card.dart';
import '../widgets/fuel_metric_display.dart';
import 'fuel_form_sheet.dart';
import '../../../../core/widgets/app_fab_location.dart';
import '../../../../core/widgets/stat_tile.dart';

/// Tab 4. Fill history with the tank each one opened, plus the grade
/// comparison that answers "is 95 actually worth it for my car?".
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final logs = ref.watch(fuelLogsProvider);
    final stats = ref.watch(fuelStatsProvider);

    // Each fill shows the tank it opened: closed tanks from the map, and the
    // newest fill the tank still running.
    final segmentByLogId = ref.watch(fuelSegmentsByLogProvider);
    final openTank = stats.openTank;
    // Lifetime figures, shared with Home and the analytics grid.
    final metrics = ref.watch(vehicleMetricsProvider);
    final padding = context.splitScreenPadding(hasFab: true);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.fuelLogs)),
      // One rule for every FAB in the app; see `AppFabLocation`.
      floatingActionButtonLocation: AppFab.of(context),
      floatingActionButton: FloatingActionButton.extended(
        // No Hero. Every tab in `StatefulShellRoute.indexedStack` stays alive
        // at once, so all four screen FABs are mounted together — and a route
        // pushed on the root navigator makes Flutter search that whole subtree
        // for heroes, where four default tags collide. These should never morph
        // into one another anyway: they belong to different tabs and do
        // different things.
        heroTag: null,
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
          // Sliver split rather than one eager `ListView`: the header cards
          // build once, and the history builds lazily so a 400-fill log costs
          // the same per frame as a 10-fill one.
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.header,
                  sliver: SliverList.list(
                    children: [
                      _FuelSummaryStrip(stats: stats),
                      if (openTank != null) ...[
                        const SizedBox(height: 20),
                        _CurrentTankCard(tank: openTank),
                      ],
                      if (metrics.byFuelType.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const _OctaneComparisonCard(),
                      ],
                      if (stats.segments.length > 1) ...[
                        const SizedBox(height: 20),
                        _EfficiencyTrendCard(stats: stats),
                      ],
                      const SizedBox(height: 20),
                      const EcoDrivingTipsCard(),
                      const SizedBox(height: 20),
                      SectionHeader(title: l10n.fuelLogs, icon: AppIcons.fuel),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: padding.list,
                  sliver: SliverList.builder(
                    itemCount: logs.length,
                    // Keyed on the log id, not the slot: the element, and with
                    // it the "already played" flag, travels with the row, so
                    // inserting or deleting never replays a neighbour's fade.
                    findChildIndexCallback: (key) => indexOfChildKey(
                      key,
                      logs.length,
                      (i) => 'fuel-${logs[i].id}',
                    ),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntranceAnimation.item(
                        key: ValueKey('fuel-${logs[i].id}'),
                        index: i,
                        child: SwipeHint(
                          list: 'fuel',
                          enabled: i == 0,
                          background: _DeleteBackground(label: l10n.delete),
                          child: _FuelLogTile(
                            log: logs[i],
                            segment: segmentByLogId[logs[i].id],
                            openTank: openTank?.log.id == logs[i].id
                                ? openTank
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
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
    final metric = ref.watch(fuelMetricProvider);
    // One source for every screen: accumulative over the tracked distance,
    // never scoped to the latest fill.
    final metrics = ref.watch(vehicleMetricsProvider);

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.fuelEconomy,
            // Counts in whichever unit is on screen: the metric converts from
            // the engine's L/100 km before the count starts.
            value: metric.of(metrics.litersPer100Km),
            format: (v) => Fmt.dec2(v, locale),
            unit: metric.unit(l10n),
            color: fuelEconomyColor(metrics.litersPer100Km),
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            // Lifetime cumulative: total fuel spend over every kilometre
            // since the vehicle's initial reading, amortising on each odometer
            // bump. Always two decimals — the engine guarantees a finite,
            // non-negative double, so `0.00` is the empty state, never a blank
            // or a dash that leaves the tile looking broken.
            label: l10n.costPerKm,
            value: metrics.fuelCostPerKm,
            format: (v) => Fmt.dec2(v, locale),
            unit: l10n.currency,
            color: AppColors.green,
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: l10n.totalCost,
            value: metrics.fuelCost,
            format: (v) => Fmt.moneyCompact(v, locale),
            unit: l10n.currency,
            color: AppColors.purple,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }
}

/// Cost per kilometre for each grade the driver has actually used, cheapest
/// first — the answer to "is 95 worth it for my car?" is a question about
/// money, and consumption alone cannot give it when the grades cost different
/// amounts.
///
/// Bars are scaled to the cheapest grade so the gap is visible even when the
/// absolute numbers are close, and each other grade says how much more it
/// costs per kilometre than that one. No minimum distance is imposed: a grade
/// is compared as soon as the car has moved on it, and one it has not moved on
/// yet says it is still being measured.
class _OctaneComparisonCard extends ConsumerWidget {
  const _OctaneComparisonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    // Same provider as the header cards: lifetime litres and spend per grade
    // over the road each grade powered. The engine ranks them cheapest per
    // kilometre first, grades not yet driven on last.
    final grades = ref.watch(vehicleMetricsProvider).byFuelType;
    final measured = grades.where((g) => g.isMeasured).toList();
    final cheapest = measured.isEmpty ? null : measured.first;

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
          for (var i = 0; i < grades.length; i++) ...[
            _OctaneRow(
              stats: grades[i],
              cheapest: cheapest,
              // A verdict needs a second measured grade to be measured
              // against.
              showVerdict: measured.length > 1,
              index: i,
              locale: locale,
              metric: metric,
            ),
            if (i < grades.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _OctaneRow extends StatelessWidget {
  const _OctaneRow({
    required this.stats,
    required this.cheapest,
    required this.showVerdict,
    required this.index,
    required this.locale,
    required this.metric,
  });

  final FuelTypeStats stats;

  /// The grade cheapest per kilometre, which every bar is scaled against;
  /// `null` when no grade has been driven on yet.
  final FuelTypeStats? cheapest;
  final bool showVerdict;
  final int index;
  final String locale;
  final FuelMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = FuelTypeStyle.color(stats.fuelType);
    final base = cheapest;
    final measured = stats.isMeasured;
    final secondary = context.text.labelSmall?.copyWith(
      color: context.tokens.textSecondary,
    );

    // Cheapest is the fullest bar; a grade twice as dear per kilometre is half
    // as long.
    final bar = !measured || base == null || stats.avgCostPerKm <= 0
        ? 0.0
        : (base.avgCostPerKm / stats.avgCostPerKm).clamp(0.0, 1.0);

    final String? verdict;
    if (!measured) {
      verdict = l10n.raw('gradeMeasuring');
    } else if (!showVerdict || base == null) {
      verdict = null;
    } else if (identical(stats, base)) {
      verdict = l10n.raw('cheapestPerKm');
    } else {
      final pct = (stats.costPremiumOver(base) * 100).round();
      final grade = l10n.raw(base.fuelType.l10nKey);
      verdict = pct == 0
          ? l10n.fmt('samePerKmAs', {'grade': grade})
          : l10n.fmt('costlierPerKm', {'pct': pct, 'grade': grade});
    }

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
            // Consumption stays on the row: the ranking is money, but litres
            // are what tells a thirstier grade from a dearer one.
            StatValue(
              value: measured
                  ? metric.format(stats.avgLitersPer100Km, locale)
                  : '—',
              unit: metric.unit(l10n),
              color: color,
              style: context.text.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedProgressBar(
          value: bar,
          color: color,
          delay:
              AppDurations.entranceStep *
              index.clamp(0, AppDurations.entranceStepCap),
        ),
        const SizedBox(height: 6),
        // Cumulative per grade: everything ever spent on it, over every
        // kilometre it has powered — including the open stretch when this is
        // the grade currently in the tank.
        Row(
          children: [
            Expanded(
              child: Text(
                '${Fmt.money(stats.totalCost, locale)} ${l10n.currency} · '
                '${measured ? Fmt.dec2(stats.avgCostPerKm, locale) : '—'} '
                '${l10n.currency}/${l10n.km}',
                style: secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${Fmt.int0(stats.totalDistanceKm, locale)} ${l10n.km}',
              style: secondary,
            ),
          ],
        ),
        if (verdict != null) ...[
          const SizedBox(height: 2),
          Text(
            verdict,
            style: context.text.labelSmall?.copyWith(
              color: !measured
                  ? context.tokens.textSecondary
                  : identical(stats, base)
                  ? AppColors.green
                  : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// The tank currently in the car, measured against the live odometer.
///
/// Nothing here waits for the next fill: the numerator was fixed when the fuel
/// was paid for, and every kilometre the master odometer gains stretches the
/// denominator, so the running cost amortises downward in real time.
class _CurrentTankCard extends ConsumerWidget {
  const _CurrentTankCard({required this.tank});

  final OpenTank tank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    final color = FuelTypeStyle.color(tank.fuelType);

    return GlassCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(
                icon: Icons.speed_rounded,
                color: color,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.currentTank, style: context.text.titleSmall),
                    const SizedBox(height: 1),
                    Text(
                      '${l10n.sinceLastFill} · '
                      '${Fmt.int0(tank.startOdometer, locale)} ${l10n.km}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PillChip(label: l10n.raw('amortising'), dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: l10n.distance,
                value: Fmt.int0(tank.distanceKm, locale),
                unit: l10n.km,
                color: color,
              ),
              _Divider(),
              _Metric(
                label: l10n.runningCostPerKm,
                value: tank.hasDistance
                    ? Fmt.dec2(tank.costPerKm, locale)
                    : '—',
                unit: l10n.currency,
              ),
              _Divider(),
              _Metric(
                label: l10n.raw('onThisTank'),
                value: tank.hasDistance
                    ? metric.format(tank.litersPer100Km, locale)
                    : '—',
                unit: metric.unit(l10n),
              ),
            ],
          ),
        ],
      ),
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

    final metric = ref.watch(fuelMetricProvider);

    // Oldest first for a left-to-right reading of time. Bars are always sized
    // on efficiency, so a taller bar means a better tank in either unit.
    final points = stats.segments.reversed.toList();
    final max = points
        .map((s) => s.efficiency)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.fuelTrend, style: context.text.titleSmall),
              ),
              const FuelMetricToggle(dense: true),
            ],
          ),
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
                        label: metric.format(points[i].litersPer100Km, locale),
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
    required this.label,
    required this.showLabel,
  });

  final double height;
  final Color color;
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
        Container(
          height: 84 * height.clamp(0.06, 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withValues(alpha: 0.45), color],
            ),
          ),
        ),
      ],
    );
  }
}

/// One fill, and underneath it the tank it opened: how far that fuel took the
/// car and what it cost per kilometre, at this fill's own price and grade.
///
/// The newest fill's tank is still running, so it shows the live figures
/// against the current odometer and says so.
class _FuelLogTile extends ConsumerWidget {
  const _FuelLogTile({required this.log, this.segment, this.openTank});

  final FuelLog log;
  final FuelSegment? segment;
  final OpenTank? openTank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metric = ref.watch(fuelMetricProvider);
    final color = FuelTypeStyle.color(log.fuelType);

    final open = openTank;
    final closed = segment;
    final ({double litersPer100Km, double costPerKm, int distanceKm})? tank =
        closed != null
        ? (
            litersPer100Km: closed.litersPer100Km,
            costPerKm: closed.costPerKm,
            distanceKm: closed.distanceKm,
          )
        : open != null
        ? (
            litersPer100Km: open.litersPer100Km,
            costPerKm: open.costPerKm,
            distanceKm: open.distanceKm,
          )
        : null;
    // Rates over a tank the car has not moved on yet would read `0.00`, which
    // looks like a measurement. A dash says "nothing to divide by yet".
    final measured = tank != null && tank.distanceKm > 0;

    return SwipeToDelete(
      dismissKey: ValueKey(log.id),
      background: _DeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      // The container, not `ref`: this row's element is gone by the time the
      // undo button can be pressed.
      onDismissed: (_) {
        final container = ProviderScope.containerOf(context, listen: false);
        final removed = log;
        container.read(fuelControllerProvider.notifier).remove(removed.id);
        showUndoSnack(
          context,
          onUndo: () =>
              container.read(fuelControllerProvider.notifier).save(removed),
        );
      },
      child: GlassCard(
        // List row: opaque surface, no backdrop blur to pay for.
        blur: false,
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
                      // **The grade gives way, never the badges.** It was a
                      // bare Text in a Row with two chips beside it, and on the
                      // newest fill — partial and in use — the row ran out of
                      // width and pushed the grade into the icon. The fill
                      // state is now an icon rather than a worded chip, and
                      // the name ellipsises if it still does not fit.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.raw(log.fuelType.l10nKey),
                              style: context.text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _FillStateIcon(full: log.isFullTank),
                          if (open != null) ...[
                            const SizedBox(width: 6),
                            PillChip(
                              label: l10n.raw('tankInUse'),
                              color: color,
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
                      '${Fmt.dec1(log.liters, locale)} ${l10n.raw(log.fuelType.volumeUnitKey)} · '
                      '${Fmt.dec2(log.pricePerLiter, locale)}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (tank != null) ...[
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
                      value: measured
                          ? metric.format(tank.litersPer100Km, locale)
                          : '—',
                      unit: metric.unit(l10n),
                      color: color,
                    ),
                    _Divider(),
                    _Metric(
                      label: l10n.costPerKm,
                      value: measured ? Fmt.dec2(tank.costPerKm, locale) : '—',
                      unit: l10n.currency,
                    ),
                    _Divider(),
                    _Metric(
                      label: l10n.distance,
                      value: Fmt.int0(tank.distanceKm, locale),
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
}

/// Full or partial fill as a glyph: a full circle for a topped-up tank, a half
/// one for a partial. Shown on every row, so the two read as a pair rather
/// than one being the absence of the other, and named for screen readers and
/// on long-press, since a glyph alone does not say what it means.
class _FillStateIcon extends StatelessWidget {
  const _FillStateIcon({required this.full});

  final bool full;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.raw(full ? 'fullTank' : 'partialFill');
    return Tooltip(
      message: label,
      child: Icon(
        full ? Icons.circle : Icons.contrast_rounded,
        size: 14,
        color: context.tokens.textSecondary,
        semanticLabel: label,
      ),
    );
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
