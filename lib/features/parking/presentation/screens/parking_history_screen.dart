import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/location_picker_screen.dart';
import '../../../../core/widgets/swipe_hint.dart';
import '../../domain/entities/saved_parking_location.dart';
import '../providers/parking_providers.dart';
import 'parking_entry_sheet.dart';
import 'parking_sheet.dart';

/// Every spot the selected car has been parked in, newest day first, so a
/// garage used weeks ago can be found again.
class ParkingHistoryScreen extends ConsumerStatefulWidget {
  const ParkingHistoryScreen({super.key});

  @override
  ConsumerState<ParkingHistoryScreen> createState() =>
      _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends ConsumerState<ParkingHistoryScreen> {
  /// The pin whose callout is open on the map.
  String? _selected;

  /// The card just scrolled to from the map, outlined for a moment so the eye
  /// lands on it.
  String? _highlighted;
  Timer? _highlightTimer;

  final Map<String, GlobalKey> _cardKeys = {};

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _showCard(String id) {
    final target = _cardKeys[id]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
    setState(() {
      _selected = null;
      _highlighted = id;
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlighted = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final history = ref.watch(vehicleParkingHistoryProvider);
    final hasPast = history.any((p) => !p.isActive);

    Future<void> clearHistory() async {
      final ok = await confirmAction(
        context,
        title: l10n.raw('parkingClearHistoryTitle'),
        message: l10n.raw('parkingClearHistoryBody'),
        confirmLabel: l10n.raw('parkingClearHistory'),
      );
      if (ok) await ref.read(parkingControllerProvider.notifier).clearHistory();
    }

    final days = <DateTime, List<SavedParkingLocation>>{};
    for (final pin in history) {
      days.putIfAbsent(DateX.dayOnly(pin.timestamp), () => []).add(pin);
    }
    final mapped = history.where((p) => p.hasFix).toList();
    final firstPast = history.where((p) => !p.isActive).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.raw('parkingHistory')),
        actions: [
          if (hasPast)
            IconButton(
              tooltip: l10n.raw('parkingClearHistory'),
              onPressed: clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: history.isEmpty
          ? AppEmptyState(
              icon: Icons.local_parking_rounded,
              title: l10n.raw('parkingHistoryEmpty'),
              message: l10n.raw('parkingHistoryEmptyHint'),
            )
          : ListView(
              padding: context.screenPadding(),
              children: [
                if (mapped.isNotEmpty) ...[
                  _HistoryMap(
                    pins: mapped,
                    selected: _selected,
                    onSelect: (id) => setState(() => _selected = id),
                    onShowCard: _showCard,
                  ),
                  const SizedBox(height: 16),
                ],
                for (final day in days.entries) ...[
                  SectionHeader(
                    title: Fmt.dateLong(day.key, locale),
                    icon: Icons.calendar_today_outlined,
                  ),
                  for (final pin in day.value)
                    Padding(
                      key: _keyFor(pin.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SwipeHint(
                        list: 'parking',
                        enabled: pin == firstPast,
                        background: SwipeDeleteBackground(label: l10n.delete),
                        child: _ParkingEntry(
                          pin: pin,
                          highlighted: pin.id == _highlighted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }
}

class _HistoryMap extends ConsumerWidget {
  const _HistoryMap({
    required this.pins,
    required this.selected,
    required this.onSelect,
    required this.onShowCard,
  });

  final List<SavedParkingLocation> pins;
  final String? selected;

  /// Opens a pin's callout, or closes it with null.
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onShowCard;

  static const double _pinSize = 36;
  static const double _calloutWidth = 210;
  static const double _calloutHeight = 96;

  static LatLng _at(SavedParkingLocation p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = [for (final p in pins) _at(p)];
    final open = pins.where((p) => p.id == selected).firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.cardRadius),
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 16,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(40),
                    maxZoom: 16,
                  )
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => onSelect(null),
          ),
          children: [
            TileLayer(
              urlTemplate: LocationPickerScreen.tileUrl,
              userAgentPackageName: LocationPickerScreen.tileUserAgent,
            ),
            MarkerLayer(
              markers: [
                // Oldest first, so the current spot is drawn on top.
                for (final pin in pins.reversed)
                  Marker(
                    point: _at(pin),
                    width: _pinSize,
                    height: _pinSize,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => onSelect(pin.id),
                      child: Icon(
                        Icons.location_on,
                        size: _pinSize,
                        color: pin.isActive ? AppColors.cyan : AppColors.red,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black45),
                        ],
                      ),
                    ),
                  ),
                // Last, so the callout sits above every pin. Its bottom
                // stays clear for the pin it belongs to.
                if (open != null)
                  Marker(
                    point: _at(open),
                    width: _calloutWidth,
                    height: _calloutHeight + _pinSize,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        _Callout(
                          pin: open,
                          height: _calloutHeight,
                          onShowCard: () => onShowCard(open.id),
                        ),
                        const SizedBox(height: _pinSize),
                      ],
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Callout extends ConsumerWidget {
  const _Callout({
    required this.pin,
    required this.height,
    required this.onShowCard,
  });

  final SavedParkingLocation pin;
  final double height;
  final VoidCallback onShowCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final name = pin.name?.trim() ?? '';

    return Material(
      color: context.colors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? l10n.raw('parkingUnnamed') : name,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${Fmt.date(pin.timestamp, locale)}  '
                '${Fmt.time(pin.timestamp, locale)}',
                style: context.text.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
              const Spacer(),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onShowCard,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(l10n.raw('parkingShowCard')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingEntry extends ConsumerWidget {
  const _ParkingEntry({required this.pin, this.highlighted = false});

  final SavedParkingLocation pin;
  final bool highlighted;

  /// In words rather than with an arrow, which Arabic would read backwards.
  String _period(AppLocalizations l10n, String locale) {
    final start = Fmt.time(pin.timestamp, locale);
    final end = pin.endedAt;
    if (end == null) return l10n.fmt('parkingSince', {'start': start});
    final sameDay = DateX.dayOnly(end) == DateX.dayOnly(pin.timestamp);
    final endText = sameDay
        ? Fmt.time(end, locale)
        : '${Fmt.date(end, locale)} ${Fmt.time(end, locale)}';
    return l10n.fmt('fromTo', {'start': start, 'end': endText});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final color = pin.isActive ? AppColors.cyan : AppColors.blue;
    final name = pin.name?.trim() ?? '';

    Future<void> launch(Future<bool> Function() open) async {
      if (!await open() && context.mounted) {
        showAppSnack(context, l10n.couldNotLaunch);
      }
    }

    final launcher = ref.read(launcherServiceProvider);
    final label = name.isEmpty ? l10n.raw('parkingUnnamed') : name;

    Future<void> found() async {
      await ref.read(parkingControllerProvider.notifier).clear();
      if (!context.mounted) return;
      showAppSnack(
        context,
        l10n.raw('parkingCleared'),
        icon: Icons.check_rounded,
      );
    }

    final actions = <Widget>[
      // On Android a route opens the same app choice as the pin, so the
      // second button would do exactly what the first does.
      if (pin.hasFix && !AppPlatform.isAndroid)
        OutlinedButton.icon(
          onPressed: () => launch(
            () => launcher.directionsTo(
              lat: pin.latitude,
              lng: pin.longitude,
              label: label,
            ),
          ),
          icon: const Icon(Icons.directions_rounded, size: 18),
          label: _ButtonLabel(l10n.raw('parkingGoThere')),
          style: _buttonStyle,
        ),
      if (pin.hasFix)
        OutlinedButton.icon(
          onPressed: () => launch(
            () => launcher.openMap(
              lat: pin.latitude,
              lng: pin.longitude,
              label: label,
            ),
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: _ButtonLabel(l10n.raw('parkingShowOnMap')),
          style: _buttonStyle,
        ),
      if (pin.isActive)
        OutlinedButton.icon(
          onPressed: found,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: _ButtonLabel(l10n.raw('parkingFound')),
          style: _buttonStyle,
        ),
    ];

    // Undo is offered before the delete, while this row can still reach the
    // messenger; the container outlives the row.
    Future<void> delete() async {
      if (!await confirmDelete(context) || !context.mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      final controller = container.read(parkingControllerProvider.notifier);
      showUndoSnack(context, onUndo: () => controller.restore(pin));
      await controller.delete(pin.id);
    }

    final card = GlassCard(
      blur: false,
      accent: color,
      // The current spot keeps its own sheet, reminder included; a past one
      // only has its words to change.
      onTap: () => pin.isActive
          ? ParkingSheet.show(context)
          : ParkingEntrySheet.show(context, pin),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(
                icon: Icons.local_parking_rounded,
                color: color,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? l10n.raw('parkingUnnamed') : name,
                      style: context.text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _period(l10n, locale),
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (pin.isActive)
                PillChip(
                  label: l10n.raw('parkingNow'),
                  color: AppColors.cyan,
                  selected: true,
                  dense: true,
                )
              else
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: delete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: context.tokens.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (pin.floorOrSection != null || pin.note != null) ...[
            const SizedBox(height: 10),
            if (pin.floorOrSection != null)
              _Detail(icon: Icons.layers_outlined, text: pin.floorOrSection!),
            if (pin.note != null)
              _Detail(icon: Icons.sticky_note_2_outlined, text: pin.note!),
          ],
          const SizedBox(height: 12),
          if (!pin.hasFix) ...[
            Text(
              l10n.raw('parkingNoFix'),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            if (actions.isNotEmpty) const SizedBox(height: 8),
          ],
          // Two to a row, so the spot the car is in now can carry "I found my
          // car" beside the map, as the dashboard card does.
          for (var i = 0; i < actions.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: actions[i]),
                if (i + 1 < actions.length) ...[
                  const SizedBox(width: 8),
                  Expanded(child: actions[i + 1]),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final framed = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
        border: Border.all(
          color: highlighted ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: card,
    );

    // The spot the car is in now is ended with "I found my car", not swiped
    // away from its own history.
    if (pin.isActive) return framed;

    return SwipeToDelete(
      dismissKey: ValueKey('dismiss-${pin.id}'),
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) {
        // The container, not `ref`: this row is gone by the time undo is tapped.
        final container = ProviderScope.containerOf(context, listen: false);
        final controller = container.read(parkingControllerProvider.notifier);
        controller.delete(pin.id);
        showUndoSnack(context, onUndo: () => controller.restore(pin));
      },
      child: framed,
    );
  }
}

final ButtonStyle _buttonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(40),
  padding: const EdgeInsets.symmetric(horizontal: 8),
);

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, textAlign: TextAlign.center),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: context.tokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    ),
  );
}
