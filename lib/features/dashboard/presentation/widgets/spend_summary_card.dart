import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/spend_composition_bar.dart';
import '../../../analytics/domain/entities/vehicle_metrics.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';

/// What the car has cost, split across the four disjoint streams that make up
/// the total, over the distance it has actually been driven.
///
/// **One card, two homes.** The dashboard and the expenses tab carried
/// near-identical copies that had drifted apart — different accent rules,
/// different bar geometry, two spellings of the same legend row. They show the
/// same figure, so looking different made them read as different numbers. This
/// is the expenses-screen design, the better of the two, with the dashboard's
/// monthly-pace stat folded back in behind [showMonthlyPace].
///
/// Cost per kilometre is the headline it exists for:
/// `(fuel + service + parts + other) / (currentOdometer - initialOdometer)`.
/// Both halves move on their own — spend when money is logged, distance when
/// the odometer is updated — so the figure falls as the car is driven.
class SpendSummaryCard extends ConsumerWidget {
  const SpendSummaryCard({super.key, this.showMonthlyPace = false});

  /// Adds the average monthly distance as a third mini-stat.
  ///
  /// The dashboard wants it: that is the one place the driver reads pace at a
  /// glance. The expenses tab does not — the list underneath is about money,
  /// and a distance-per-month figure there is a non sequitur.
  final bool showMonthlyPace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metrics = ref.watch(vehicleMetricsProvider);
    final monthly = showMonthlyPace ? ref.watch(monthlyPaceProvider) : null;

    final streams = _streams(l10n, metrics);

    // The card takes the accent of whatever the driver actually spends most
    // on, so the surround shifts with the data instead of being a fixed hue.
    final dominant = streams.reduce((a, b) => a.amount >= b.amount ? a : b);
    final accent = metrics.totalSpend > 0 ? dominant.color : AppColors.purple;

    // No entrance animation of its own: it appears in two places, and a card
    // that animates itself animates again wherever it is placed inside
    // something that already has an arrival.
    return GlassCard(
      accent: accent,
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
          AnimatedCounter(
            value: metrics.totalSpend,
            format: (v) => Fmt.money(v, locale),
            builder: (context, text) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: StatValue(
                value: text,
                unit: l10n.currency,
                style: context.text.displaySmall,
                animate: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // One glance shows whether fuel or repairs dominate.
          SpendCompositionBar(
            segments: [
              for (final stream in streams)
                SpendSegment(amount: stream.amount, color: stream.color),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stream in streams)
                if (stream.alwaysShow || stream.amount > 0)
                  _SpendLegend(
                    color: stream.color,
                    label: stream.label,
                    value: Fmt.money(stream.amount, locale),
                  ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: context.tokens.border, height: 1),
          const SizedBox(height: 14),
          _StatRow(metrics: metrics, locale: locale, monthlyPace: monthly),
          if (!metrics.hasDistance) ...[
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
    );
  }

  /// The five disjoint cost streams, in the order they appear in both the bar
  /// and the legend. Declared once so the two cannot fall out of step.
  List<_SpendStream> _streams(AppLocalizations l10n, VehicleMetrics m) => [
    _SpendStream(l10n.tabFuel, m.fuelCost, AppColors.cyan),
    _SpendStream(
      l10n.raw('scheduledMaintenance'),
      m.serviceCost,
      AppColors.amber,
    ),
    // **Repairs get their own band, in red, and only when there are any.**
    // Folding a breakdown into the maintenance figure answers neither of the
    // questions this card exists for: whether the schedule is expensive, and
    // whether this car keeps failing. A driver with no repairs should not be
    // shown an empty red band suggesting otherwise.
    _SpendStream(
      l10n.raw('unscheduledRepairs'),
      m.repairCost,
      AppColors.red,
      alwaysShow: false,
    ),
    // Parts fitted *during* a service are already priced into the maintenance
    // figure; this is standalone replacements only, and usually zero — so it
    // is the one row the legend drops rather than showing an empty entry.
    _SpendStream(
      l10n.raw('consumableParts'),
      m.partsCost,
      AppColors.teal,
      alwaysShow: false,
    ),
    _SpendStream(
      l10n.raw('operationalExpenses'),
      m.otherCost,
      AppColors.purple,
    ),
  ];
}

class _SpendStream {
  const _SpendStream(
    this.label,
    this.amount,
    this.color, {
    this.alwaysShow = true,
  });

  final String label;
  final double amount;
  final Color color;

  /// Whether the legend lists this stream even at zero.
  final bool alwaysShow;
}

/// The mini-stats under the hairline: cost per kilometre, the distance it was
/// measured over, and optionally the monthly pace.
///
/// Start-aligned throughout. The columns share one leading edge and each grows
/// downward from the top rather than centring inside a stretched cell — under
/// `stretch` the taller column, the one carrying the odometer caption, pushed
/// its neighbours' labels out of line.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.metrics,
    required this.locale,
    this.monthlyPace,
  });

  final VehicleMetrics metrics;
  final String locale;

  /// `null` drops the third column entirely rather than showing a dash.
  final double? monthlyPace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pace = monthlyPace;

    final stats = <Widget>[
      _MiniStat(
        label: l10n.costPerKm,
        value: Fmt.dec2(metrics.totalCostPerKm, locale),
        unit: '${l10n.currency}/${l10n.km}',
        color: AppColors.green,
      ),
      _MiniStat(
        // The denominator, shown beside the ratio it produced, with the two
        // readings it came from underneath: a zero here is almost always a
        // wrong starting reading, and this makes that visible.
        label: l10n.raw('trackedDistance'),
        value: Fmt.int0(metrics.trackedDistanceKm, locale),
        unit: l10n.km,
        color: AppColors.cyan,
        caption:
            '${Fmt.int0(metrics.initialOdometer, locale)}'
            ' → '
            '${Fmt.int0(metrics.currentOdometer, locale)}',
      ),
      if (pace != null)
        _MiniStat(
          label: l10n.avgMonthly,
          value: pace <= 0 ? '—' : Fmt.int0(pace, locale),
          unit: l10n.km,
          color: AppColors.purple,
        ),
    ];

    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) _StatDivider(color: context.tokens.border),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: i == 0 ? 0 : 10,
                  end: i == stats.length - 1 ? 0 : 10,
                ),
                child: stats[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One legend entry: a dot, the stream's name, and what it cost.
class _SpendLegend extends StatelessWidget {
  const _SpendLegend({
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
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          maxLines: 1,
          style: AppTypography.numeric(
            context.text.labelSmall,
          ).copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Hairline between two mini-stats.
///
/// A plain `VerticalDivider` takes its height from a stretched row; once the
/// row start-aligns it collapses to nothing. A fixed height keeps the rule
/// visible and independent of how tall the tallest column happens to be.
class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 42, color: color);
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
    final subtle = context.text.labelSmall?.copyWith(
      color: context.tokens.textSecondary,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: subtle,
          ),
        ),
        const SizedBox(height: 6),
        // A `FittedBox` sizes itself to the scaled child, so on its own it
        // would sit wherever the column put it. `Align` pins it to the leading
        // edge, which keeps the values on one vertical line.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
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
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                caption!,
                maxLines: 1,
                textAlign: TextAlign.start,
                style: AppTypography.numeric(subtle),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
