import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/invoice_viewer.dart';
import '../../domain/entities/maintenance_record.dart';

/// Everything one service entry recorded: what it cost, where it was done,
/// what was fitted, what was checked, and the invoices for it.
///
/// **A sheet rather than a dialog.** The content is a variable-length list —
/// nine parts and four receipts on a major service, two lines on a top-up —
/// and a dialog answers that by capping its own height and scrolling inside a
/// box that floats in the middle of the screen. A draggable sheet lets the
/// driver pull the detail up to whatever height they need, keeps the reading
/// surface anchored to the thumb rather than the centre of the screen, and
/// leaves the confirm/cancel shape to the questions that actually ask one.
class ServiceDetailsSheet extends StatelessWidget {
  const ServiceDetailsSheet({super.key, required this.record});

  final MaintenanceRecord record;

  /// Opens on the **root** navigator so the floating navigation bar cannot
  /// render over the sheet or swallow its taps, carrying the caller's provider
  /// container across the root overlay the same way `showAppSheet` does.
  ///
  /// The theme's drag handle is switched off because this sheet draws its own:
  /// the framework's sits at the top of the sheet's *route*, which with a
  /// [DraggableScrollableSheet] inside is the full height of the screen.
  static Future<void> show(BuildContext context, MaintenanceRecord record) {
    final container = ProviderScope.containerOf(context, listen: false);

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: ServiceDetailsSheet(record: record),
      ),
    );
  }

  /// Whether there is anything at all worth opening the sheet for.
  static bool hasDetail(MaintenanceRecord record) =>
      record.replacedParts.isNotEmpty ||
      record.inspectedKeys.isNotEmpty ||
      record.customItems.isNotEmpty ||
      record.invoiceAttachments.isNotEmpty ||
      (record.notes?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // Sized by its content inside a modal route, not stretched to the screen.
      expand: false,
      initialChildSize: 0.66,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.66],
      builder: (context, controller) =>
          _Body(record: record, controller: controller),
    );
  }
}

/// Header and action pinned, detail scrolling between them.
///
/// The scroll controller belongs to the [DraggableScrollableSheet]: handing it
/// to the middle list is what makes a drag that starts on the content resize
/// the sheet before it scrolls, instead of doing one or the other.
class _Body extends StatelessWidget {
  const _Body({required this.record, required this.controller});

  final MaintenanceRecord record;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tierColor = Color(record.tier.colorValue);
    final workshop = record.workshopName?.trim() ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const _DragHandle(),
          _Header(record: record, locale: locale, accent: tierColor),
          Divider(height: 1, color: context.tokens.border),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              children: [
                _InfoGrid(record: record, locale: locale, workshop: workshop),
                if (record.replacedParts.isNotEmpty)
                  _Section(
                    icon: Icons.build_rounded,
                    label: l10n.replaceAndChange,
                    color: AppColors.green,
                    count: record.replacedParts.length,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final part in record.replacedParts)
                          PillChip(
                            label: l10n.raw(part.l10nKey),
                            color: AppColors.green,
                            selected: true,
                            icon: Icons.check_circle_outline_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                if (record.customItems.isNotEmpty)
                  _Section(
                    icon: Icons.edit_note_rounded,
                    label: l10n.raw('customItems'),
                    color: AppColors.purple,
                    count: record.customItems.length,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in record.customItems)
                          _BulletLine(text: item, color: AppColors.purple),
                      ],
                    ),
                  ),
                if (record.inspectedKeys.isNotEmpty)
                  _Section(
                    icon: Icons.search_rounded,
                    label: l10n.inspectAndReview,
                    color: AppColors.amber,
                    count: record.inspectedKeys.length,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final key in record.inspectedKeys)
                          _BulletLine(
                            text: l10n.raw(key),
                            color: AppColors.amber,
                          ),
                      ],
                    ),
                  ),
                if (record.notes?.isNotEmpty ?? false)
                  _Section(
                    icon: Icons.sticky_note_2_outlined,
                    label: l10n.notes,
                    color: AppColors.cyan,
                    child: Text(
                      record.notes!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.tokens.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                if (record.invoiceAttachments.isNotEmpty)
                  _Section(
                    icon: Icons.receipt_long_rounded,
                    label: l10n.raw('invoiceAttachment'),
                    color: AppColors.blue,
                    count: record.invoiceAttachments.length,
                    child: _AttachmentStrip(
                      attachments: record.invoiceAttachments,
                    ),
                  ),
                if (!ServiceDetailsSheet.hasDetail(record))
                  Text(
                    l10n.raw('noPartsRecorded'),
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          _ActionArea(accent: tierColor),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: context.tokens.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Status, title, and when the work was carried out.
class _Header extends StatelessWidget {
  const _Header({
    required this.record,
    required this.locale,
    required this.accent,
  });

  final MaintenanceRecord record;
  final String locale;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = record.isCompleted;
    // The completion timestamp when there is one; a booking has only the date
    // it is booked for, and saying so beats presenting an appointment as if it
    // had already happened.
    final stamp = done
        ? (record.completedDate ?? record.date)
        : (record.scheduledDate ?? record.date);
    final stampLabel = done
        ? l10n.raw('completionDate')
        : l10n.raw('appointmentDate');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccentIconBadge(
            icon: AppIcons.of(record.tier.iconKey),
            color: accent,
            size: 46,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: PillChip(
                        label: done
                            ? l10n.raw('done')
                            : l10n.raw('statusBooked'),
                        color: done ? AppColors.green : AppColors.amber,
                        icon: done
                            ? Icons.check_circle_rounded
                            : Icons.event_rounded,
                        selected: true,
                        dense: true,
                      ),
                    ),
                    if (record.tier.isCorrective) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: PillChip(
                          label: l10n.raw('correctiveService'),
                          color: accent,
                          icon: Icons.report_problem_rounded,
                          selected: true,
                          dense: true,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  record.title,
                  style: context.text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$stampLabel · ${Fmt.dateLong(stamp, locale)}',
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.close,
          ),
        ],
      ),
    );
  }
}

/// The four figures a driver checks first, as a two-column grid.
///
/// The workshop takes a full row of its own: a name is the one value here that
/// is prose rather than a number, and half a column truncates most of them.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({
    required this.record,
    required this.locale,
    required this.workshop,
  });

  final MaintenanceRecord record;
  final String locale;
  final String workshop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        // **`IntrinsicHeight`, not a stretched `Row`.** These tiles sit in a
        // `ListView`, so the row's vertical constraint is unbounded and
        // `CrossAxisAlignment.stretch` would resolve to an infinite tight
        // height. This measures the taller tile and matches the other to it,
        // which is the alignment the grid actually wants.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.speed_rounded,
                  label: l10n.raw('currentOdometer'),
                  color: AppColors.cyan,
                  child: StatValue(
                    value: Fmt.int0(record.odometer, locale),
                    unit: l10n.km,
                    style: context.text.titleSmall,
                    animate: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: Icons.payments_outlined,
                  label: l10n.raw('totalCost'),
                  color: AppColors.green,
                  child: record.cost > 0
                      ? StatValue(
                          value: Fmt.money(record.cost, locale),
                          unit: l10n.currency,
                          style: context.text.titleSmall,
                          animate: false,
                        )
                      : const _NoValue(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.store_mall_directory_outlined,
          label: l10n.raw('workshop'),
          color: AppColors.purple,
          child: workshop.isEmpty
              ? const _NoValue()
              : Text(
                  workshop,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: context.tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(alignment: AlignmentDirectional.centerStart, child: child),
        ],
      ),
    );
  }
}

/// An empty figure, drawn rather than hidden — the tile is there to answer the
/// question, and a missing answer is one.
class _NoValue extends StatelessWidget {
  const _NoValue();

  @override
  Widget build(BuildContext context) => Text(
    '—',
    style: context.text.titleSmall?.copyWith(
      color: context.tokens.textSecondary,
    ),
  );
}

/// Labelled block: a coloured heading with an optional count, then content.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
    this.count,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  count == null ? label : '$label ($count)',
                  style: context.text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, end: 9),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The attached invoices as tappable thumbnails.
///
/// **Decoded once, in [initState].** The sheet rebuilds as it is dragged, and
/// base64-decoding four receipts on every frame of that gesture is the kind of
/// cost that shows up as a stutter rather than an error. An entry that will not
/// decode — an older row, a partial sync — is dropped from the strip instead of
/// throwing inside a sheet the driver is reading; [InvoiceViewer] still gets
/// the full list, so the page indices line up with what is stored.
class _AttachmentStrip extends StatefulWidget {
  const _AttachmentStrip({required this.attachments});

  final List<String> attachments;

  static const double _size = 96;

  @override
  State<_AttachmentStrip> createState() => _AttachmentStripState();
}

class _AttachmentStripState extends State<_AttachmentStrip> {
  late final List<({int index, Uint8List bytes})> _thumbnails = [
    for (var i = 0; i < widget.attachments.length; i++)
      if (_decode(widget.attachments[i]) case final bytes?)
        (index: i, bytes: bytes),
  ];

  static Uint8List? _decode(String encoded) {
    if (encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnails.isEmpty) {
      return Text(
        context.l10n.raw('invoiceNone'),
        style: context.text.bodySmall?.copyWith(
          color: context.tokens.textSecondary,
        ),
      );
    }

    return SizedBox(
      height: _AttachmentStrip._size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _thumbnails.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, position) {
          final item = _thumbnails[position];
          return SizedBox(
            width: _AttachmentStrip._size,
            child: Material(
              color: context.tokens.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => InvoiceViewer.show(
                  context,
                  attachments: widget.attachments,
                  initialPage: item.index,
                ),
                // `contain`, not `cover`: a receipt cropped to fill the square
                // is a receipt with its total cut off.
                child: Image.memory(
                  item.bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The way out, held above the home indicator and separated from the content
/// it scrolls under.
class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(context.l10n.close),
            style: FilledButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.16),
              foregroundColor: accent,
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
