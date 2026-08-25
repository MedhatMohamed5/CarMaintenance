import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../dashboard/presentation/widgets/parts_health_card.dart';
import '../../domain/entities/part_health.dart';
import '../../domain/entities/maintenance_record.dart';
import '../providers/maintenance_providers.dart';
import '../widgets/service_parts_dialog.dart';
import 'service_form_sheet.dart';
import '../../../../core/widgets/app_fab_location.dart';

/// Tab 2. What has already been done, and the wear picture that follows from
/// it. History and health live together because one explains the other.
class MaintenanceLogScreen extends ConsumerWidget {
  const MaintenanceLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final records = ref.watch(maintenanceRecordsProvider);
    final padding = context.splitScreenPadding(hasFab: true);

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
      // One rule for every FAB in the app; see `AppFabLocation`.
      floatingActionButtonLocation: AppFab.of(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ServiceFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.logService),
        backgroundColor: AppColors.green,
        foregroundColor: context.colors.onSecondary,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding.header,
            sliver: SliverList.list(
              children: [
                // The wear picture lives on Home. Here it is one tap behind a
                // button so the same card is not rendered on two screens.
                const _ConsumablesButton(),
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
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: padding.list,
            sliver: SliverList.builder(
              itemCount: records.length,
              findChildIndexCallback: (key) => indexOfChildKey(
                key,
                records.length,
                (i) => 'service-${records[i].id}',
              ),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EntranceAnimation.item(
                  key: ValueKey('service-${records[i].id}'),
                  index: i,
                  child: _RecordTile(record: records[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One completed service.
///
/// Deliberately flat: title, when and where, and what it cost. The parts and
/// checks that used to expand inline now live behind an explicit button, which
/// keeps a long history scannable instead of turning each row into a panel.
/// Opens the consumables wear picture as a sheet.
///
/// The card itself renders on Home; duplicating it here meant the same list
/// was built and laid out twice on every navigation. This is the entry point,
/// and it shows the headline — how many parts need attention — so the button
/// still says something without drawing the whole card.
class _ConsumablesButton extends ConsumerWidget {
  const _ConsumablesButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final health = ref.watch(partsHealthProvider);
    final due = health.where((p) => p.isOverdue).length;
    final warning = health
        .where((p) => p.status == HealthStatus.warning)
        .length;
    final accent = due > 0
        ? AppColors.red
        : warning > 0
        ? AppColors.amber
        : AppColors.green;

    return GlassCard(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => AllPartsSheet.show(context),
      child: Row(
        children: [
          AccentIconBadge(
            icon: Icons.monitor_heart_outlined,
            color: accent,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.consumablesHealth, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _subtitle(l10n, due: due, warning: warning),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.tokens.textSecondary,
          ),
        ],
      ),
    );
  }

  String _subtitle(
    AppLocalizations l10n, {
    required int due,
    required int warning,
  }) {
    if (due > 0) return '$due · ${l10n.raw('overdue')}';
    if (warning > 0) return '$warning · ${l10n.raw('dueSoon')}';
    return l10n.raw('allPartsHealthy');
  }
}

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});

  final MaintenanceRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final tierColor = Color(record.tier.colorValue);
    final partCount = record.replacedParts.length;
    final hasDetail = ServicePartsDialog.hasDetail(record);

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) =>
          ref.read(maintenanceControllerProvider.notifier).remove(record.id),
      child: GlassCard(
        // List row: opaque surface, no backdrop blur to pay for.
        blur: false,
        accent: tierColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        // Tapping the card edits; the parts button is the only other action,
        // so neither gesture has to be guessed at.
        onTap: () => ServiceFormSheet.show(context, existing: record),
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
                      Text(
                        record.title,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.date(record.date, locale)} · '
                        '${Fmt.int0(record.odometer, locale)} ${l10n.km}'
                        '${record.workshopName?.isNotEmpty ?? false ? ' · ${record.workshopName}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record.cost > 0) ...[
                  const SizedBox(width: 8),
                  StatValue(
                    value: Fmt.money(record.cost, locale),
                    unit: l10n.currency,
                    style: context.text.titleSmall,
                    animate: false,
                  ),
                ],
              ],
            ),
            if (hasDetail) ...[
              const SizedBox(height: 10),
              _PartsButton(
                record: record,
                partCount: partCount,
                color: tierColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the parts summary. Labelled with the count so the row still says how
/// much was done without listing it.
class _PartsButton extends StatelessWidget {
  const _PartsButton({
    required this.record,
    required this.partCount,
    required this.color,
  });

  final MaintenanceRecord record;
  final int partCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = partCount > 0
        ? '${l10n.raw('viewReplacedParts')} ($partCount)'
        : l10n.raw('viewReplacedParts');

    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => ServicePartsDialog.show(context, record),
        icon: const Icon(Icons.receipt_long_outlined, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size.fromHeight(38),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: AlignmentDirectional.center,
        ),
      ),
    );
  }
}
