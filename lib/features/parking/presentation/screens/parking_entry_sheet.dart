import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/saved_parking_location.dart';
import '../providers/parking_providers.dart';

/// Edits the words on a past parking spot: its name, floor and note.
///
/// Where and when the car was parked are recorded, not typed, and stay as
/// they are. The spot the car is in now opens [ParkingSheet] instead.
class ParkingEntrySheet extends ConsumerStatefulWidget {
  const ParkingEntrySheet({super.key, required this.pin});

  final SavedParkingLocation pin;

  static Future<void> show(BuildContext context, SavedParkingLocation pin) =>
      showAppSheet(
        context: context,
        builder: (_) => ParkingEntrySheet(pin: pin),
      );

  @override
  ConsumerState<ParkingEntrySheet> createState() => _ParkingEntrySheetState();
}

class _ParkingEntrySheetState extends ConsumerState<ParkingEntrySheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.pin.name ?? '',
  );
  late final TextEditingController _floor = TextEditingController(
    text: widget.pin.floorOrSection ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.pin.note ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _floor.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    await ref
        .read(parkingControllerProvider.notifier)
        .updateEntry(
          widget.pin,
          name: _name.text,
          note: _note.text,
          floorOrSection: _floor.text,
        );
    if (!mounted) return;
    Navigator.of(context).maybePop();
    showAppSnack(context, l10n.raw('saved'), icon: Icons.check_rounded);
  }

  Future<void> _delete() {
    final container = ProviderScope.containerOf(context, listen: false);
    final pin = widget.pin;
    return deleteFromSheet(
      context,
      delete: () =>
          container.read(parkingControllerProvider.notifier).delete(pin.id),
      onUndo: () =>
          container.read(parkingControllerProvider.notifier).restore(pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final parkedAt = widget.pin.timestamp;

    return AppSheetScaffold(
      title: l10n.raw('parkingEditSpot'),
      icon: Icons.local_parking_rounded,
      accent: AppColors.cyan,
      isSubmitting: _saving,
      onSubmit: _save,
      onDelete: _delete,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: context.tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.raw('parkingParkedAt'),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${Fmt.date(parkedAt, locale)}  ${Fmt.time(parkedAt, locale)}',
              style: context.text.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _name,
          label: l10n.raw('parkingNameLabel'),
          hint: l10n.raw('parkingNameHint'),
          prefixIcon: Icons.place_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _floor,
          label: l10n.raw('parkingFloorLabel'),
          hint: l10n.raw('parkingFloorHint'),
          prefixIcon: Icons.layers_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _note,
          label: l10n.raw('parkingNoteLabel'),
          hint: l10n.raw('parkingNoteHint'),
          prefixIcon: Icons.sticky_note_2_outlined,
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
