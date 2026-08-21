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
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../dashboard/presentation/widgets/parts_health_card.dart';
import '../../domain/entities/maintenance_record.dart';
import '../providers/maintenance_providers.dart';
import 'service_form_sheet.dart';

/// Tab 2. What has already been done, and the wear picture that follows from
/// it. History and health live together because one explains the other.
class MaintenanceLogScreen extends ConsumerWidget {
  const MaintenanceLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final records =
        ref.watch(maintenanceRecordsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.maintenanceHistory),
        actions: [
          IconButton(
            tooltip: l10n.serviceRoadmap,
            onPressed: () => context.push(AppRoutes.schedule),
            icon: const Icon(Icons.event_note_rounded),
          ),
          IconButton(
            tooltip: l10n.consumablesHealth,
            onPressed: () => AllPartsSheet.show(context),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ServiceFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.logService),
        backgroundColor: AppColors.green,
        foregroundColor: context.colors.onSecondary,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                80 + MediaQuery.paddingOf(context).bottom,
              ),
        children: [
          const PartsHealthCard(),
          const SizedBox(height: 20),
          SectionHeader(
            title: '${l10n.completedServices} (${records.length})',
            icon: AppIcons.serviceLog,
          ),
          if (records.isEmpty)
            AppEmptyState(
              icon: AppIcons.serviceLog,
              title: l10n.noMaintenanceLogs,
              message: l10n.raw('addFirstEntry'),
              actionLabel: l10n.logService,
              onAction: () => ServiceFormSheet.show(context),
            )
          else
            for (var i = 0; i < records.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecordTile(record: records[i])
                    .animate()
                    .fadeIn(delay: (40 * i.clamp(0, 8)).ms, duration: 300.ms)
                    .slideY(begin: 0.04),
              ),
        ],
      ),
    );
  }
}

class _RecordTile extends ConsumerStatefulWidget {
  const _RecordTile({required this.record});

  final MaintenanceRecord record;

  @override
  ConsumerState<_RecordTile> createState() => _RecordTileState();
}

class _RecordTileState extends ConsumerState<_RecordTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final r = widget.record;
    final tierColor = Color(r.tier.colorValue);
    final hasDetail =
        r.replacedParts.isNotEmpty ||
        r.inspectedKeys.isNotEmpty ||
        (r.notes?.isNotEmpty ?? false);

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) =>
          ref.read(maintenanceControllerProvider.notifier).remove(r.id),
      child: GlassCard(
        accent: tierColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: hasDetail
            ? () => setState(() => _expanded = !_expanded)
            : () => ServiceFormSheet.show(context, existing: r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccentIconBadge(
                  icon: AppIcons.serviceLog,
                  color: tierColor,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.date(r.date, locale)} · '
                        '${Fmt.int0(r.odometer, locale)} ${l10n.km}'
                        '${r.workshopName?.isNotEmpty ?? false ? ' · ${r.workshopName}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.cost > 0)
                  StatValue(
                    value: Fmt.money(r.cost, locale),
                    unit: l10n.currency,
                    style: context.text.titleSmall,
                    animate: false,
                  ),
                if (hasDetail)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: context.tokens.textSecondary,
                    ),
                  ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.replacedParts.isNotEmpty) ...[
                      _GroupHeader(
                        icon: Icons.build_rounded,
                        label: l10n.replaceAndChange,
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final part in r.replacedParts)
                            PillChip(
                              label: l10n.raw(part.l10nKey),
                              color: AppColors.green,
                              selected: true,
                              icon: Icons.check_circle_outline_rounded,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (r.inspectedKeys.isNotEmpty) ...[
                      _GroupHeader(
                        icon: Icons.search_rounded,
                        label: l10n.inspectAndReview,
                        color: AppColors.amber,
                      ),
                      const SizedBox(height: 6),
                      for (final key in r.inspectedKeys)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.raw(key),
                                style: context.text.bodySmall?.copyWith(
                                  color: context.tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                    if (r.notes?.isNotEmpty ?? false)
                      Text(
                        r.notes!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ServiceFormSheet.show(context, existing: r),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(l10n.edit),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
