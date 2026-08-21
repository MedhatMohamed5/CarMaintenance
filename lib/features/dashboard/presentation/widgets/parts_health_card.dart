import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';

/// The consumable-parts visualiser.
///
/// Each row is a bar whose colour comes from the health ramp, so severity is
/// legible before any number is read. Tapping a row expands it to reveal the
/// projected due date and a one-tap "I replaced this" reset.
class PartsHealthCard extends ConsumerWidget {
  const PartsHealthCard({super.key, this.showAll = false});

  /// The dashboard shows the six headline parts; the maintenance tab passes
  /// `true` to show the full catalogue.
  final bool showAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final parts = showAll
        ? ref.watch(allPartsHealthProvider)
        : ref.watch(partsHealthProvider);

    if (parts.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.consumablesHealth, style: context.text.titleSmall),
          const SizedBox(height: 14),
          for (var i = 0; i < parts.length; i++)
            PartHealthRow(health: parts[i], index: i),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 380.ms).slideY(begin: 0.05);
  }
}

class PartHealthRow extends ConsumerStatefulWidget {
  const PartHealthRow({super.key, required this.health, this.index = 0});

  final PartHealth health;
  final int index;

  @override
  ConsumerState<PartHealthRow> createState() => _PartHealthRowState();
}

class _PartHealthRowState extends ConsumerState<PartHealthRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final h = widget.health;
    final color = AppColors.health(h.fractionRemaining);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AccentIconBadge(
                  icon: AppIcons.of(h.part.iconKey),
                  color: Color(h.part.colorValue),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.raw(h.part.l10nKey),
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (h.isOverdue)
                  PillChip(
                    label: l10n.overdue,
                    color: AppColors.red,
                    selected: true,
                    dense: true,
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: Fmt.int0(h.remainingKm, locale),
                          style: context.text.titleSmall?.copyWith(
                            color: color,
                          ),
                        ),
                        TextSpan(
                          text: ' ${l10n.km} ${l10n.remaining}',
                          style: context.text.labelSmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedProgressBar(
              value: h.fractionRemaining,
              color: color,
              delay: Duration(milliseconds: 70 * widget.index),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.consumed} ${Fmt.int0(h.consumedKm, locale)} ${l10n.km}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${l10n.lifespan} ${Fmt.int0(h.lifespanKm, locale)} ${l10n.km}',
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
            // Expanding a row is where the detail lives — the collapsed state
            // stays scannable, which matters with a dozen parts on screen.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h.estimatedDueDate != null)
                      _DetailLine(
                        icon: AppIcons.calendar,
                        label: l10n.estimatedDate,
                        value: Fmt.date(h.estimatedDueDate!, locale),
                      ),
                    _DetailLine(
                      icon: AppIcons.odometer,
                      label: l10n.nextService,
                      value:
                          '${Fmt.int0(h.dueAtOdometer, locale)} ${l10n.km}',
                    ),
                    if (h.limitedByTime)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.raw('basedOnYourDriving'),
                          style: context.text.labelSmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _confirmReset(context),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(l10n.resetPart),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
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

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetPart),
        content: Text(l10n.resetPartHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref
        .read(maintenanceControllerProvider.notifier)
        .resetPart(widget.health.part);
    if (!context.mounted) return;
    setState(() => _expanded = false);
    showAppSnack(context, l10n.raw('saved'), icon: Icons.check_rounded);
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: context.tokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
          Text(value, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

/// Full-catalogue sheet reachable from the maintenance tab.
class AllPartsSheet extends StatelessWidget {
  const AllPartsSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showAppSheet(context: context, builder: (_) => const AllPartsSheet());

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.consumablesHealth,
                  style: context.text.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: const PartsHealthCard(showAll: true),
          ),
        ),
      ],
    );
  }
}
