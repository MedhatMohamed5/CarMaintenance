import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/location_service.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../../vehicles/presentation/widgets/vehicle_required.dart';
import '../providers/parking_providers.dart';

/// Pin the car's spot, or edit the details of the pin already saved.
///
/// One sheet for both, because they are the same conversation at different
/// moments: the first time you have coordinates and no words for them, and the
/// second time you remember the bay number on the way to the lift. What the
/// primary button does changes; the fields do not.
class ParkingSheet extends ConsumerStatefulWidget {
  const ParkingSheet({super.key});

  static Future<void> show(BuildContext context) async {
    if (!await VehicleRequired.ensure(context) || !context.mounted) return;
    return showAppSheet(context: context, builder: (_) => const ParkingSheet());
  }

  @override
  ConsumerState<ParkingSheet> createState() => _ParkingSheetState();
}

class _ParkingSheetState extends ConsumerState<ParkingSheet> {
  late final TextEditingController _floor;
  late final TextEditingController _note;

  /// The move-the-car reminder chosen in this sheet. [_remindTouched] tells
  /// "left alone" apart from "chose off", which only matters for a pin that
  /// already carries a reminder: saving its words should not quietly drop it.
  Duration? _remindIn;
  bool _remindTouched = false;

  @override
  void initState() {
    super.initState();
    // Seeded from the saved pin so reopening the sheet shows what is already
    // written rather than making the driver type it again.
    final saved = ref.read(activeParkingProvider);
    _floor = TextEditingController(text: saved?.floorOrSection ?? '');
    _note = TextEditingController(text: saved?.note ?? '');
  }

  @override
  void dispose() {
    _floor.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pin() async {
    final l10n = context.l10n;
    final saved = await ref
        .read(parkingControllerProvider.notifier)
        .pinCurrentPosition(
          note: _note.text,
          floorOrSection: _floor.text,
          remindIn: _remindIn,
        );

    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).maybePop();
      showAppSnack(
        context,
        l10n.raw('parkingSaved'),
        icon: Icons.check_rounded,
      );
    }
  }

  Future<void> _updateDetails() async {
    final l10n = context.l10n;
    final controller = ref.read(parkingControllerProvider.notifier);
    await controller.updateDetails(
      note: _note.text,
      floorOrSection: _floor.text,
    );
    if (_remindTouched) await controller.setReminder(_remindIn);

    if (!mounted) return;
    Navigator.of(context).maybePop();
    showAppSnack(context, l10n.raw('saved'), icon: Icons.check_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saved = ref.watch(activeParkingProvider);
    // Reached with an empty garage anyway — a deleted vehicle, a restored
    // route. The opener normally stops this; a form that cannot save is not
    // the place to find that out.
    if (ref.watch(vehiclesProvider).isEmpty) return const NoVehicleFallback();

    final busy = ref.watch(parkingControllerProvider).isLoading;
    final failure = ref.watch(parkingFailureProvider);
    final locale = ref.watch(localeTagProvider);

    return AppSheetScaffold(
      title: l10n.raw('parkingTitle'),
      icon: Icons.local_parking_rounded,
      accent: AppColors.cyan,
      isSubmitting: busy,
      // The sheet's primary action is context-driven: pin the spot when there
      // is none, save the words when there already is one.
      submitLabel: saved == null
          ? l10n.raw('parkingSave')
          : l10n.raw('parkingUpdate'),
      onSubmit: busy ? null : (saved == null ? _pin : _updateDetails),
      children: [
        if (saved != null) ...[
          _SavedSummary(
            label: l10n.raw('parkingParkedAt'),
            value: Fmt.date(saved.timestamp, locale),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Text(
            l10n.raw('parkingEmptyHint'),
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
        ],
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
        const SizedBox(height: 14),
        _ReminderChoice(
          selected: _remindIn,
          touched: _remindTouched,
          existing: saved?.remindAt,
          onChanged: (value) => setState(() {
            _remindIn = value;
            _remindTouched = true;
          }),
        ),
        if (failure != null) ...[
          const SizedBox(height: 14),
          _FailureNotice(failure: failure),
        ],
        // Re-pinning is offered separately once a spot exists: the primary
        // button then saves the words, and moving the pin is a different
        // intention — you have parked somewhere else.
        if (saved != null) ...[
          const SizedBox(height: 16),
          AppActionButton(
            icon: busy
                ? Icons.gps_not_fixed_rounded
                : Icons.my_location_rounded,
            label: busy ? l10n.raw('parkingLocating') : l10n.raw('parkingSave'),
            color: AppColors.cyan,
            style: AppActionStyle.outlined,
            onPressed: busy ? null : _pin,
          ),
        ],
      ],
    );
  }
}

/// "Remind me to move the car", as a handful of durations from now.
///
/// Durations rather than a clock: the driver reads a meter or a sign that says
/// "two hours", and translating that into a time of day is work the app can
/// do. A pin that already has a reminder says when it is due until another
/// choice is made.
class _ReminderChoice extends StatelessWidget {
  const _ReminderChoice({
    required this.selected,
    required this.touched,
    required this.existing,
    required this.onChanged,
  });

  final Duration? selected;
  final bool touched;
  final DateTime? existing;
  final ValueChanged<Duration?> onChanged;

  static const List<Duration?> _options = [
    null,
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
  ];

  static String _labelKey(Duration? d) => switch (d?.inHours) {
    null => 'parkingRemindOff',
    1 => 'parkingRemind1h',
    2 => 'parkingRemind2h',
    _ => 'parkingRemind3h',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = existing != null && existing!.isAfter(DateTime.now());
    // Untouched, a pin with a live reminder shows no chip as chosen — none of
    // them is what it holds — and says when it is due instead.
    bool isSelected(Duration? option) =>
        touched ? option == selected : (!pending && option == null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.raw('parkingRemindLabel'),
          style: context.text.labelMedium?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _options)
              PillChip(
                label: l10n.raw(_labelKey(option)),
                icon: option == null
                    ? Icons.notifications_off_outlined
                    : Icons.timer_outlined,
                color: AppColors.cyan,
                selected: isSelected(option),
                dense: true,
                onTap: () => onChanged(option),
              ),
          ],
        ),
        if (pending && !touched) ...[
          const SizedBox(height: 6),
          Text(
            l10n.fmt('parkingRemindAt', {
              'time': MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(existing!)),
            }),
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedSummary extends StatelessWidget {
  const _SavedSummary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.local_parking_rounded,
        size: 18,
        color: context.tokens.textSecondary,
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: context.tokens.textSecondary,
        ),
      ),
      const Spacer(),
      Text(value, style: context.text.labelMedium),
    ],
  );
}

/// Says which of the location problems happened, and offers the one action
/// that can fix it.
class _FailureNotice extends ConsumerWidget {
  const _FailureNotice({required this.failure});

  final LocationFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final message = switch (failure) {
      LocationFailure.serviceDisabled => l10n.raw('parkingErrService'),
      LocationFailure.denied => l10n.raw('parkingErrDenied'),
      LocationFailure.deniedForever => l10n.raw('parkingErrForever'),
      LocationFailure.unavailable => l10n.raw('parkingErrUnavailable'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: context.text.bodySmall)),
            ],
          ),
          // Only a permanently blocked permission has somewhere to send the
          // user; the rest are fixed by trying again.
          if (failure == LocationFailure.deniedForever) ...[
            const SizedBox(height: 10),
            AppActionButton(
              icon: Icons.settings_outlined,
              label: l10n.raw('parkingOpenSettings'),
              color: AppColors.amber,
              style: AppActionStyle.outlined,
              dense: true,
              onPressed: () => ref.read(locationServiceProvider).openSettings(),
            ),
          ],
        ],
      ),
    );
  }
}
