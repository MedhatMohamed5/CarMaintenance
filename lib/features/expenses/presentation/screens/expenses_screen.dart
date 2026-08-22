import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../analytics/presentation/providers/vehicle_metrics_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/summarize_expenses.dart';
import '../providers/expense_providers.dart';
import 'expense_form_sheet.dart';

/// Tab 5. Everything the car costs outside fuel and scheduled service, with a
/// breakdown that shows where the money actually goes.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(expenseSummaryProvider);
    final expenses = ref.watch(filteredExpensesProvider);
    final padding = context.splitScreenPadding(hasFab: true);
    final hasAny = (ref.watch(expensesProvider)).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.expenses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ExpenseFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.add),
        backgroundColor: AppColors.purple,
        foregroundColor: context.colors.onTertiary,
      ),
      body: !hasAny
          ? AppEmptyState(
              icon: AppIcons.expenses,
              title: l10n.noExpenses,
              message: l10n.raw('addFirstEntry'),
              actionLabel: l10n.addExpense,
              onAction: () => ExpenseFormSheet.show(context),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.header,
                  sliver: SliverList.list(
                    children: [
                      const _TotalsCard(),
                      if (summary.slices.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _BreakdownCard(summary: summary),
                      ],
                      if (summary.monthlyTotals.length > 1) ...[
                        const SizedBox(height: 20),
                        _MonthlyTrendCard(summary: summary),
                      ],
                      const SizedBox(height: 20),
                      const _CategoryFilterRow(),
                      const SizedBox(height: 12),
                      if (expenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            l10n.noExpenses,
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: padding.list,
                  sliver: SliverList.builder(
                    itemCount: expenses.length,
                    findChildIndexCallback: (key) => indexOfChildKey(
                      key,
                      expenses.length,
                      (i) => 'expense-${expenses[i].id}',
                    ),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntranceAnimation.item(
                        key: ValueKey('expense-${expenses[i].id}'),
                        index: i,
                        step: const Duration(milliseconds: 35),
                        child: _ExpenseTile(expense: expenses[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Everything the vehicle has cost, over everything it has driven.
///
/// Reads [vehicleMetricsProvider] — the same object Home and the fuel tab use —
/// so the headline here can never disagree with the one on the dashboard. It
/// covers **all four** spend streams, not just the free-form expenses listed
/// below it: the list is a filter on one category, the total never is.
class _TotalsCard extends ConsumerWidget {
  const _TotalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final metrics = ref.watch(vehicleMetricsProvider);

    return GlassCard(
      accent: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.totalSpend,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: StatValue(
              value: Fmt.money(metrics.totalSpend, locale),
              unit: l10n.currency,
              style: context.text.headlineSmall,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: context.tokens.border, height: 1),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TotalsStat(
                    label: l10n.costPerKm,
                    value: Fmt.dec2(metrics.totalCostPerKm, locale),
                    unit: '${l10n.currency}/${l10n.km}',
                    color: AppColors.green,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.tokens.border,
                ),
                Expanded(
                  child: _TotalsStat(
                    label: l10n.raw('trackedDistance'),
                    value: Fmt.int0(metrics.trackedDistanceKm, locale),
                    unit: l10n.km,
                    color: AppColors.cyan,
                    caption:
                        '${Fmt.int0(metrics.initialOdometer, locale)}'
                        ' → '
                        '${Fmt.int0(metrics.currentOdometer, locale)}',
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

class _TotalsStat extends StatelessWidget {
  const _TotalsStat({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
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
          const SizedBox(height: 5),
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
      ),
    );
  }
}

class _BreakdownCard extends ConsumerWidget {
  const _BreakdownCard({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final top = summary.slices.first.share;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.breakdown, style: context.text.titleSmall),
          const SizedBox(height: 16),
          for (var i = 0; i < summary.slices.length; i++) ...[
            _SliceRow(
              slice: summary.slices[i],
              // Scaled against the largest slice so small categories stay
              // visible instead of collapsing to a sliver.
              relative: top <= 0 ? 0 : summary.slices[i].share / top,
              index: i,
              locale: locale,
            ),
            if (i < summary.slices.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SliceRow extends StatelessWidget {
  const _SliceRow({
    required this.slice,
    required this.relative,
    required this.index,
    required this.locale,
  });

  final ExpenseSlice slice;
  final double relative;
  final int index;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Color(slice.category.colorValue);

    return Column(
      children: [
        Row(
          children: [
            Icon(AppIcons.of(slice.category.iconKey), size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.raw(slice.category.l10nKey),
                style: context.text.labelMedium,
              ),
            ),
            Text(
              '${(slice.share * 100).toStringAsFixed(0)}%',
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            StatValue(
              value: Fmt.money(slice.total, locale),
              unit: l10n.currency,
              color: color,
              style: context.text.titleSmall,
              animate: false,
            ),
          ],
        ),
        const SizedBox(height: 7),
        AnimatedProgressBar(
          value: relative,
          color: color,
          height: 7,
          delay: Duration(milliseconds: 60 * index),
        ),
      ],
    );
  }
}

class _MonthlyTrendCard extends ConsumerWidget {
  const _MonthlyTrendCard({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    // Last twelve months keeps the bars readable on a phone.
    final entries = summary.monthlyTotals.entries.toList();
    final shown = entries.length > 12
        ? entries.sublist(entries.length - 12)
        : entries;
    final max = shown
        .map((e) => e.value)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.avgMonthly, style: context.text.titleSmall),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: max <= 0
                                  ? 0
                                  : (shown[i].value / max).clamp(0.05, 1.0),
                            ),
                            duration: Duration(milliseconds: 600 + i * 50),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, _) => Container(
                              height: 78 * t,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.purple.withValues(alpha: 0.4),
                                    AppColors.purple,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Fmt.monthShort(shown[i].key, locale),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: context.text.labelSmall?.copyWith(
                              fontSize: 9,
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ],
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

class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(expenseFilterProvider);

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PillChip(
            label: l10n.all,
            selected: selected == null,
            onTap: () => ref.read(expenseFilterProvider.notifier).state = null,
          ),
          for (final c in ExpenseCategory.values) ...[
            const SizedBox(width: 8),
            PillChip(
              label: l10n.raw(c.l10nKey),
              color: Color(c.colorValue),
              icon: AppIcons.of(c.iconKey),
              selected: selected == c,
              onTap: () => ref.read(expenseFilterProvider.notifier).state =
                  selected == c ? null : c,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final color = Color(expense.category.colorValue);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) =>
          ref.read(expenseControllerProvider.notifier).remove(expense.id),
      child: GlassCard(
        // List row: opaque surface, no backdrop blur to pay for.
        blur: false,
        accent: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => ExpenseFormSheet.show(context, existing: expense),
        child: Row(
          children: [
            AccentIconBadge(
              icon: AppIcons.of(expense.category.iconKey),
              color: color,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.raw(expense.category.l10nKey)} · '
                    '${Fmt.date(expense.date, locale)}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatValue(
              value: Fmt.money(expense.amount, locale),
              unit: l10n.currency,
              color: color,
              style: context.text.titleSmall,
              animate: false,
            ),
          ],
        ),
      ),
    );
  }
}
