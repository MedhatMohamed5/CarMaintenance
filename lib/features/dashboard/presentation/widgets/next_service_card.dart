import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../maintenance/domain/entities/next_service_due.dart';
import '../../../maintenance/domain/entities/service_catalog.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';

class NextServiceCard extends ConsumerWidget {
  const NextServiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final due = ref.watch(nextServiceDueProvider);
    if (due == null) return const SizedBox.shrink();

    final tierColor = Color(due.tier.colorValue);
    final last = due.lastService;
    final span = last == null
        ? ServiceCatalog.intervalKm
        : (due.targetOdometer - last.odometer).clamp(1, 1 << 30);
    final travelled = span - due.kmRemaining;
    final progress = (travelled / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('nextServiceDue'),
          icon: AppIcons.schedule,
          actionLabel: l10n.viewAll,
          onAction: () => context.push(AppRoutes.schedule),
        ),
        GlassCard(
          accent: tierColor,
          elevated: true,
          onTap: () => context.push(AppRoutes.schedule),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AccentIconBadge(
                    icon: AppIcons.serviceLog,
                    color: tierColor,
                    size: 44,
                    filled: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.raw(due.tier.l10nKey),
                          style: context.text.titleLarge?.copyWith(
                            color: tierColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          last == null
                              ? l10n.raw('noServiceYet')
                              : l10n.fmt('basedOnLastService', {
                                  'n': Fmt.int0(last.odometer, locale),
                                }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(due: due),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: AppIcons.odometer,
                      label: l10n.nextService,
                      value: Fmt.int0(due.targetOdometer, locale),
                      unit: l10n.km,
                      color: tierColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: context.tokens.border,
                  ),
                  Expanded(
                    child: _Metric(
                      icon: AppIcons.calendar,
                      label: l10n.estimatedDate,
                      value: due.targetDate == null
                          ? '—'
                          : Fmt.date(due.targetDate!, locale),
                      unit: due.targetDate == null
                          ? ''
                          : l10n.raw(
                              due.dueDriver == DueDriver.time
                                  ? 'dueByTime'
                                  : 'dueByDistance',
                            ),
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedProgressBar(
                value: progress,
                color: due.isOverdue ? AppColors.red : tierColor,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      due.kmRemaining < 0
                          ? l10n.fmt('kmOverdueLabel', {
                              'n': Fmt.int0(due.kmRemaining.abs(), locale),
                            })
                          : l10n.fmt('kmRemainingLabel', {
                              'n': Fmt.int0(due.kmRemaining, locale),
                            }),
                      style: context.text.labelMedium?.copyWith(
                        color: due.isOverdue ? AppColors.red : tierColor,
                      ),
                    ),
                  ),
                  if (due.dailyPace > 0)
                    Text(
                      '${Fmt.int0(due.dailyPace, locale)} ${l10n.km}/${l10n.day}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 170.ms, duration: 380.ms).slideY(begin: 0.05);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.due});

  final NextServiceDue due;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (due.isOverdue) {
      return PillChip(
        label: l10n.overdue,
        color: AppColors.red,
        icon: Icons.priority_high_rounded,
        selected: true,
        dense: true,
      );
    }
    if (due.isDueSoon) {
      return PillChip(
        label: l10n.dueSoon,
        color: AppColors.amber,
        icon: Icons.schedule_rounded,
        selected: true,
        dense: true,
      );
    }
    return PillChip(
      label: l10n.healthy,
      color: AppColors.green,
      icon: Icons.check_circle_rounded,
      selected: true,
      dense: true,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: context.tokens.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        StatValue(
          value: value,
          unit: unit.isEmpty ? null : unit,
          color: color,
          style: context.text.titleMedium,
          animate: false,
        ),
      ],
    );
  }
}
