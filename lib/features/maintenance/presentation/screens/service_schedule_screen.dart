import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/upcoming_service.dart';
import '../providers/maintenance_providers.dart';
import 'service_form_sheet.dart';

/// Tab 3. The periodic-service roadmap: every 10,000 km stop, what it covers,
/// how far away it is, and the date the driver's own pace projects for it.
class ServiceScheduleScreen extends ConsumerWidget {
  const ServiceScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicle = ref.watch(selectedVehicleProvider);
    final roadmap = ref.watch(serviceRoadmapProvider);
    final pace = ref.watch(dailyPaceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.serviceRoadmap)),
      body: vehicle == null
          ? AppEmptyState(
              icon: AppIcons.vehicle,
              title: l10n.raw('addVehicleToView'),
              message: l10n.noVehiclesHint,
            )
          : roadmap.isEmpty
          ? AppEmptyState(
              icon: AppIcons.schedule,
              title: l10n.raw('noSchedule'),
            )
          : ListView(
              padding: context.screenPadding(),
              children: [
                _PaceCard(dailyKm: pace),
                const SizedBox(height: 20),
                SectionHeader(
                  title: l10n.upcomingServices,
                  icon: AppIcons.schedule,
                ),
                for (var i = 0; i < roadmap.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EntranceAnimation.item(
                      key: ValueKey('milestone-${roadmap[i].milestone.id}'),
                      index: i,
                      step: const Duration(milliseconds: 50),
                      duration: const Duration(milliseconds: 320),
                      slide: 0.05,
                      child: _MilestoneCard(
                        service: roadmap[i],
                        locale: locale,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The number every projection on this screen depends on, stated openly so the
/// dates never look like magic.
class _PaceCard extends ConsumerWidget {
  const _PaceCard({required this.dailyKm});

  final double dailyKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    return GlassCard(
      accent: AppColors.cyan,
      child: Row(
        children: [
          const AccentIconBadge(
            icon: Icons.route_rounded,
            color: AppColors.cyan,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.raw('basedOnYourDriving'),
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (dailyKm <= 0)
                  Text(
                    l10n.raw('notEnoughData'),
                    style: context.text.titleSmall,
                  )
                else
                  Row(
                    children: [
                      StatValue(
                        value: Fmt.int0(dailyKm, locale),
                        unit: '${l10n.km}/${l10n.day}',
                        color: AppColors.cyan,
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(width: 14),
                      StatValue(
                        value: Fmt.int0(dailyKm * 30.44, locale),
                        unit: '${l10n.km}/${l10n.month}',
                        style: context.text.titleMedium,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends HookWidget {
  const _MilestoneCard({required this.service, required this.locale});

  final UpcomingService service;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(service.isOverdue || service.isDueSoon);
    final l10n = context.l10n;
    final s = service;
    final ms = s.milestone;
    final tierColor = Color(s.tier.colorValue);
    final dimmed = s.isCompleted;

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: GlassCard(
        accent: dimmed ? null : tierColor,
        onTap: () => expanded.value = !expanded.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.raw(s.tier.l10nKey),
                        style: context.text.titleLarge?.copyWith(
                          color: dimmed
                              ? context.tokens.textSecondary
                              : tierColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Fact(
                            icon: AppIcons.odometer,
                            text:
                                '${Fmt.int0(ms.targetOdometer, locale)} ${l10n.km}',
                          ),
                          _Fact(
                            icon: AppIcons.calendar,
                            text: l10n.fmt('monthsLabel', {
                              'n': ms.recommendedMonths,
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(service: s),
              ],
            ),
            if (!s.isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.isOverdue
                          ? l10n.fmt('kmOverdueLabel', {
                              'n': Fmt.int0(s.kmRemaining.abs(), locale),
                            })
                          : l10n.fmt('kmRemainingLabel', {
                              'n': Fmt.int0(s.kmRemaining, locale),
                            }),
                      style: context.text.labelMedium?.copyWith(
                        color: s.isOverdue ? AppColors.red : tierColor,
                      ),
                    ),
                  ),
                  if (s.estimatedDate != null)
                    Text(
                      '${l10n.raw('estimated')} · '
                      '${Fmt.date(s.estimatedDate!, locale)}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: expanded.value
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Divider(color: context.tokens.border),
                  const SizedBox(height: 12),
                  _ChecklistGroup(
                    icon: Icons.build_rounded,
                    label: l10n.replaceAndChange,
                    color: AppColors.green,
                    items: [
                      for (final p in ms.replaceParts) l10n.raw(p.l10nKey),
                      for (final p in ms.conditionalParts)
                        '${l10n.raw(p.l10nKey)} (${l10n.raw('optional')})',
                    ],
                    checked: true,
                  ),
                  const SizedBox(height: 14),
                  _ChecklistGroup(
                    icon: Icons.search_rounded,
                    label: l10n.inspectAndReview,
                    color: AppColors.amber,
                    items: [for (final k in ms.inspectKeys) l10n.raw(k)],
                    checked: false,
                  ),
                  const SizedBox(height: 16),
                  if (s.isCompleted)
                    OutlinedButton.icon(
                      onPressed: () =>
                          ServiceFormSheet.show(context, fromMilestone: s),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.edit),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: tierColor,
                        side: BorderSide(
                          color: tierColor.withValues(alpha: 0.45),
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () =>
                          ServiceFormSheet.show(context, fromMilestone: s),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.markDone),
                      style: FilledButton.styleFrom(
                        backgroundColor: tierColor,
                        foregroundColor: context.colors.onPrimary,
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.service});

  final UpcomingService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (service.isCompleted) {
      return PillChip(
        label: l10n.raw('done'),
        color: AppColors.green,
        icon: Icons.check_circle_rounded,
        selected: true,
        dense: true,
      );
    }
    if (service.isOverdue) {
      return PillChip(
        label: l10n.overdue,
        color: AppColors.red,
        icon: Icons.priority_high_rounded,
        selected: true,
        dense: true,
      );
    }
    if (service.isDueSoon) {
      return PillChip(
        label: l10n.dueSoon,
        color: AppColors.amber,
        icon: Icons.warning_amber_rounded,
        selected: true,
        dense: true,
      );
    }
    return const SizedBox.shrink();
  }
}

class _ChecklistGroup extends StatelessWidget {
  const _ChecklistGroup({
    required this.icon,
    required this.label,
    required this.color,
    required this.items,
    required this.checked,
  });

  final IconData icon;
  final String label;
  final Color color;
  final List<String> items;

  /// Replace-items render as ticked chips; inspect-items as a bulleted list —
  /// the visual difference is the point of the two groups.
  final bool checked;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$label:',
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (checked)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                PillChip(
                  label: item,
                  color: color,
                  selected: true,
                  icon: Icons.check_circle_outline_rounded,
                  dense: true,
                ),
            ],
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: context.tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.tokens.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: context.text.labelSmall),
        ],
      ),
    );
  }
}
