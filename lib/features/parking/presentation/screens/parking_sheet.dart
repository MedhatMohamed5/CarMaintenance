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

  /// Retries the pin when the driver comes back from a settings screen the
  /// failure notice sent them to, so switching location on is the last thing
  /// they have to do rather than one more tap after it.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Seeded from the saved pin so reopening the sheet shows what is already
    // written rather than making the driver type it again.
    final saved = ref.read(activeParkingProvider);
    _floor = TextEditingController(text: saved?.floorOrSection ?? '');
    _note = TextEditingController(text: saved?.note ?? '');
    _lifecycle = AppLifecycleListener(onResume: _retryAfterSettings);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _floor.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Set only when this sheet sent the driver to a settings screen, so the
  /// retry follows that trip and nothing else. The permission dialog resumes
  /// the app too, and retrying on it would ask again the instant they said no.
  bool _retryOnResume = false;

  void _retryAfterSettings() {
    if (!_retryOnResume) return;
    _retryOnResume = false;
    if (!mounted || ref.read(parkingControllerProvider).isLoading) return;
    _pin();
  }

  void _openSettings(Future<void> Function() open) {
    _retryOnResume = true;
    open();
  }

  /// Switches location on in place where the platform can — Android's own
  /// dialog, without leaving the app — and pins as soon as it is on. Declining
  /// leaves the notice up; only a device with no such dialog is sent to the
  /// settings screen, as before.
  ///
  /// The dialog pauses and resumes the app as well, which is why it does not
  /// go through [_openSettings]: the pin here follows the answer itself.
  Future<void> _turnOnLocation() async {
    final service = ref.read(locationServiceProvider);
    final enabled = await service.requestService();
    if (!mounted) return;
    if (enabled == null) {
      _openSettings(service.openLocationSettings);
    } else if (enabled && !ref.read(parkingControllerProvider).isLoading) {
      _pin();
    }
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
          held: saved?.remindAfter,
          onChanged: (value) => setState(() {
            _remindIn = value;
            _remindTouched = true;
          }),
        ),
        if (failure != null) ...[
          const SizedBox(height: 14),
          _FailureNotice(
            failure: failure,
            onRetry: busy ? null : _pin,
            onOpenSettings: _openSettings,
            onTurnOnLocation: _turnOnLocation,
          ),
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
/// do. A pin that already has a reminder marks the period it was set with and
/// says when it is due, until another choice is made.
class _ReminderChoice extends StatelessWidget {
  const _ReminderChoice({
    required this.selected,
    required this.touched,
    required this.existing,
    required this.held,
    required this.onChanged,
  });

  final Duration? selected;
  final bool touched;
  final DateTime? existing;

  /// The period the saved reminder was set with, when it is known.
  final Duration? held;
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
    // Untouched, a pin with a live reminder marks the period it was set with.
    // Leaving it marked does not restart it — only tapping a chip does, since
    // a choice is always measured from the moment it is made. A pin from
    // before the period was stored, whose reminder was changed after parking,
    // has no period to mark and shows the due time alone.
    bool isSelected(Duration? option) => touched
        ? option == selected
        : pending
        ? held != null && option == held
        : option == null;

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
  const _FailureNotice({
    required this.failure,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onTurnOnLocation,
  });

  final LocationFailure failure;

  /// Pins again — which asks for the permission first when it is missing.
  final VoidCallback? onRetry;

  /// Opens a settings screen through the sheet, which pins again once the
  /// driver comes back from it.
  final void Function(Future<void> Function() open) onOpenSettings;

  /// Switches location on in place, falling back to the settings screen.
  final VoidCallback onTurnOnLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final message = switch (failure) {
      LocationFailure.serviceDisabled => l10n.raw('parkingErrService'),
      LocationFailure.denied => l10n.raw('parkingErrDenied'),
      LocationFailure.deniedForever => l10n.raw('parkingErrForever'),
      LocationFailure.unavailable => l10n.raw('parkingErrUnavailable'),
    };

    // One way out per cause, each to the exact place that fixes it: the
    // location switch is the device's — turned on in place where Android
    // allows it — the permission is this app's, and a permanent refusal can
    // only be lifted from the app's settings page. A fix that simply did not
    // arrive has nothing to open — saving again is the retry.
    final service = ref.read(locationServiceProvider);
    final (IconData, String, VoidCallback?)? action = switch (failure) {
      LocationFailure.serviceDisabled => (
        Icons.location_on_outlined,
        l10n.raw('parkingEnableLocation'),
        onTurnOnLocation,
      ),
      LocationFailure.denied => (
        Icons.my_location_rounded,
        l10n.raw('parkingAllowLocation'),
        onRetry,
      ),
      LocationFailure.deniedForever => (
        Icons.settings_outlined,
        l10n.raw('parkingOpenSettings'),
        () => onOpenSettings(service.openSettings),
      ),
      LocationFailure.unavailable => null,
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
          if (action != null) ...[
            const SizedBox(height: 10),
            AppActionButton(
              icon: action.$1,
              label: action.$2,
              color: AppColors.amber,
              style: AppActionStyle.outlined,
              dense: true,
              onPressed: action.$3,
            ),
          ],
        ],
      ),
    );
  }
}
