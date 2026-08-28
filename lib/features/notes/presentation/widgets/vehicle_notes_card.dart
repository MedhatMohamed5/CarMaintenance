import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/note_providers.dart';

/// The dashboard's checklist teaser.
///
/// **Renders nothing once every note is done.** Same rule as `ParkingCard`:
/// a card that only ever nags belongs on screen exactly as long as there is
/// something to nag about, and disappears the moment the list is clear.
class VehicleNotesCard extends ConsumerWidget {
  const VehicleNotesCard({super.key});

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openNotesProvider);
    if (open.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final preview = open.take(_previewCount);
    final remaining = open.length - preview.length;

    return GlassCard(
      accent: AppColors.amber,
      onTap: () => context.push(AppRoutes.notes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(
                icon: Icons.checklist_rounded,
                color: AppColors.amber,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.notes, style: context.text.titleSmall)),
              Text(
                l10n.fmt('notesOpenLabel', {'n': open.length}),
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final note in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (remaining > 0)
            Text(
              l10n.fmt('notesOpenLabel', {'n': remaining}),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
