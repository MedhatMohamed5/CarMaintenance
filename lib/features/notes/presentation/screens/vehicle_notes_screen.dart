import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_fab_location.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/vehicle_note.dart';
import '../providers/note_providers.dart';
import 'note_form_sheet.dart';

/// The full per-vehicle checklist: every open item first, done ones after —
/// reached from the dashboard's [VehicleNotesCard] or the quick-action tile.
class VehicleNotesScreen extends ConsumerWidget {
  const VehicleNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = ref.watch(notesProvider);
    final open = notes.where((n) => !n.isDone).toList();
    final done = notes.where((n) => n.isDone).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.notes)),
      floatingActionButtonLocation: AppFab.of(context),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => NoteFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.raw('addNote')),
        backgroundColor: AppColors.amber,
        foregroundColor: context.colors.onTertiary,
      ),
      body: notes.isEmpty
          ? AppEmptyState(
              icon: Icons.checklist_rounded,
              title: l10n.raw('noNotes'),
              message: l10n.raw('noNotesHint'),
              actionLabel: l10n.raw('addNote'),
              onAction: () => NoteFormSheet.show(context),
            )
          : ListView(
              padding: context.splitScreenPadding(hasFab: true).header,
              children: [
                if (open.isNotEmpty) ...[
                  SectionHeader(
                    title: l10n.raw('notesSectionOpen'),
                    icon: Icons.checklist_rounded,
                  ),
                  for (var i = 0; i < open.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntranceAnimation.item(
                        key: ValueKey('note-${open[i].id}'),
                        index: i,
                        step: AppDurations.entranceStep,
                        duration: AppDurations.entrance,
                        slide: 0.05,
                        child: _NoteTile(note: open[i]),
                      ),
                    ),
                ],
                if (done.isNotEmpty) ...[
                  if (open.isNotEmpty) const SizedBox(height: 10),
                  SectionHeader(
                    title: l10n.raw('notesSectionDone'),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  for (final note in done)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NoteTile(
                        key: ValueKey('note-${note.id}'),
                        note: note,
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({super.key, required this.note});

  final VehicleNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final done = note.isDone;

    return Dismissible(
      key: ValueKey('dismiss-${note.id}'),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) =>
          ref.read(noteControllerProvider.notifier).remove(note.id),
      child: GlassCard(
        blur: false,
        accent: done ? context.tokens.textSecondary : AppColors.amber,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => NoteFormSheet.show(context, existing: note),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkResponse(
              onTap: () =>
                  ref.read(noteControllerProvider.notifier).toggleDone(note),
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? AppColors.green : AppColors.amber,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note.text,
                  style: context.text.bodyMedium?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? context.tokens.textSecondary : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
