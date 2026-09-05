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
import '../../../../core/widgets/invoice_viewer.dart';
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
    final records = ref.watch(completedRecordsProvider);
    final bookings = ref.watch(scheduledRecordsProvider);
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
        // No Hero. Every tab in `StatefulShellRoute.indexedStack` stays alive
        // at once, so all four screen FABs are mounted together — and a route
        // pushed on the root navigator makes Flutter search that whole subtree
        // for heroes, where four default tags collide. These should never morph
        // into one another anyway: they belong to different tabs and do
        // different things.
        heroTag: null,
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
                // Bookings first, and only when there are any. What is coming
                // is what the driver has to act on; the log behind it is
                // reference material.
                if (bookings.isNotEmpty) ...[
                  SectionHeader(
                    title: '${l10n.raw('bookedServices')} (${bookings.length})',
                    icon: AppIcons.schedule,
                  ),
                  for (final booking in bookings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingTile(
                        key: ValueKey('booking-${booking.id}'),
                        record: booking,
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
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

/// One booked service, waiting to be confirmed as done.
///
/// **Visually a different thing from a log row, on purpose.** Amber accent, a
/// badge saying when it is, and a confirm button along the bottom — so a glance
/// down the screen separates what is coming from what has happened without
/// reading a single date. A missed appointment turns red rather than
/// disappearing: an unconfirmed booking is a question the driver still has to
/// answer.
class _BookingTile extends ConsumerWidget {
  const _BookingTile({super.key, required this.record});

  final MaintenanceRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final missed = record.isMissedBooking;
    final accent = missed ? AppColors.red : AppColors.amber;
    final when = record.scheduledDate ?? record.date;
    final workshop = record.workshopName ?? '';

    return Dismissible(
      key: ValueKey('booking-dismiss-${record.id}'),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) {
        final container = ProviderScope.containerOf(context, listen: false);
        final removed = record;
        container
            .read(maintenanceControllerProvider.notifier)
            .remove(removed.id);
        showUndoSnack(
          context,
          onUndo: () => container
              .read(maintenanceControllerProvider.notifier)
              .save(removed),
        );
      },
      child: GlassCard(
        blur: false,
        accent: accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: () => ServiceFormSheet.show(context, existing: record),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccentIconBadge(
                  icon: AppIcons.schedule,
                  color: accent,
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
                        '${Fmt.date(when, locale)}'
                        '${workshop.isEmpty ? '' : ' · $workshop'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: _countdown(l10n, record),
                  color: accent,
                  selected: true,
                  icon: missed
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _confirm(context, ref),
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(
                  l10n.raw('markCompleted'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// How far off the appointment is, in the words a driver would use.
  static String _countdown(AppLocalizations l10n, MaintenanceRecord record) {
    final days = record.daysUntilScheduled ?? 0;
    if (days < 0) return l10n.fmt('bookingDaysLate', {'n': -days});
    if (days == 0) return l10n.raw('bookingToday');
    if (days == 1) return l10n.raw('bookingTomorrow');
    return l10n.fmt('bookingInDays', {'n': days});
  }

  /// Confirms the service, on a date the driver picks.
  ///
  /// **The date is asked for rather than assumed.** A booking is confirmed
  /// whenever the driver next opens the app, which is regularly days after the
  /// work — and stamping today onto a service done last Tuesday quietly
  /// corrupts every interval the schedule projects from it. The appointment
  /// date is the default because it is right far more often than today is.
  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final scheduled = record.scheduledDate ?? record.date;
    final now = DateTime.now();

    final on = await showDatePicker(
      context: context,
      helpText: l10n.raw('markCompletedTitle'),
      // Never a future date: a service cannot have been carried out tomorrow.
      // Confirming early falls back to today rather than refusing.
      initialDate: scheduled.isAfter(now) ? now : scheduled,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (on == null || !context.mounted) return;

    final ok = await confirmAction(
      context,
      message: l10n.raw('markCompletedHint'),
      confirmLabel: l10n.raw('markCompleted'),
      destructive: false,
    );
    if (!ok || !context.mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    await container
        .read(maintenanceControllerProvider.notifier)
        .markCompleted(record, on: on);
    if (!context.mounted) return;
    showAppSnack(context, l10n.raw('saved'), icon: Icons.check_rounded);
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
      // The container, not `ref`: this row's element is gone by the time the
      // undo button can be pressed.
      onDismissed: (_) {
        final container = ProviderScope.containerOf(context, listen: false);
        final removed = record;
        container
            .read(maintenanceControllerProvider.notifier)
            .remove(removed.id);
        showUndoSnack(
          context,
          onUndo: () => container
              .read(maintenanceControllerProvider.notifier)
              .save(removed),
        );
      },
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
                  icon: AppIcons.of(record.tier.iconKey),
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
                // **Only repairs are badged.** A scheduled service is the
                // expected case and needs no label; marking every row would
                // make the exception invisible again. The red accent already
                // separates them at a glance — this says why.
                if (record.tier.isCorrective) ...[
                  const SizedBox(width: 8),
                  PillChip(
                    label: l10n.raw('correctiveService'),
                    color: tierColor,
                    selected: true,
                    icon: Icons.report_problem_rounded,
                  ),
                ],
                if (record.invoiceAttachments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InvoiceCountChip(
                    attachments: record.invoiceAttachments,
                    color: tierColor,
                  ),
                ],
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
