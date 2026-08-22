import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../../../core/widgets/app_sheet.dart';

/// What a single service actually touched: parts replaced, items inspected,
/// anything typed in by hand, and the technician's note.
///
/// Lives in a dialog rather than inline in the log list. Nine chips and a
/// bulleted inspection list under every row turned the history into a wall;
/// here the detail is one deliberate tap away and gets the room to be legible.
class ServicePartsDialog extends StatelessWidget {
  const ServicePartsDialog({super.key, required this.record});

  final MaintenanceRecord record;

  /// Opens on the **root** navigator so the floating navigation bar cannot
  /// render over the dialog or swallow its taps.
  static Future<void> show(BuildContext context, MaintenanceRecord record) =>
      showAppDialog<void>(
        context: context,
        builder: (_) => ServicePartsDialog(record: record),
      );

  /// Whether there is anything at all worth opening the dialog for.
  static bool hasDetail(MaintenanceRecord record) =>
      record.replacedParts.isNotEmpty ||
      record.inspectedKeys.isNotEmpty ||
      record.customItems.isNotEmpty ||
      (record.notes?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tierColor = Color(record.tier.colorValue);

    return AlertDialog(
      backgroundColor: context.colors.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccentIconBadge(
            icon: Icons.build_circle_rounded,
            color: tierColor,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.date(record.date, locale)} · '
                  '${Fmt.int0(record.odometer, locale)} ${l10n.km}',
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        // Caps the height so a 20-item service scrolls instead of overflowing,
        // and keeps the dialog off the screen edges on a small phone.
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (record.replacedParts.isNotEmpty) ...[
                _SectionLabel(
                  icon: Icons.build_rounded,
                  label: l10n.replaceAndChange,
                  color: AppColors.green,
                  count: record.replacedParts.length,
                ),
                const SizedBox(height: 10),
                Wrap(
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
                const SizedBox(height: 18),
              ],
              if (record.customItems.isNotEmpty) ...[
                _SectionLabel(
                  icon: Icons.edit_note_rounded,
                  label: l10n.raw('customItems'),
                  color: AppColors.purple,
                  count: record.customItems.length,
                ),
                const SizedBox(height: 8),
                for (final item in record.customItems)
                  _BulletLine(text: item, color: AppColors.purple),
                const SizedBox(height: 14),
              ],
              if (record.inspectedKeys.isNotEmpty) ...[
                _SectionLabel(
                  icon: Icons.search_rounded,
                  label: l10n.inspectAndReview,
                  color: AppColors.amber,
                  count: record.inspectedKeys.length,
                ),
                const SizedBox(height: 8),
                for (final key in record.inspectedKeys)
                  _BulletLine(text: l10n.raw(key), color: AppColors.amber),
                const SizedBox(height: 14),
              ],
              if (record.notes?.isNotEmpty ?? false) ...[
                _SectionLabel(
                  icon: Icons.sticky_note_2_outlined,
                  label: l10n.notes,
                  color: AppColors.cyan,
                ),
                const SizedBox(height: 8),
                Text(
                  record.notes!,
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (!hasDetail(record))
                Text(
                  l10n.raw('noPartsRecorded'),
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
    this.count,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
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
