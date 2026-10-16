import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/location_picker_screen.dart';
import '../../domain/entities/saved_parking_location.dart';
import '../providers/parking_providers.dart';

/// Every spot the selected car has been parked in, newest day first, so a
/// garage used weeks ago can be found again.
class ParkingHistoryScreen extends ConsumerWidget {
  const ParkingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _HistoryMap(pins: mapped),
                  const SizedBox(height: 16),
                ],
                for (final day in days.entries) ...[
                  SectionHeader(
                    title: Fmt.dateLong(day.key, locale),
                    icon: Icons.calendar_today_outlined,
                  ),
                  for (final pin in day.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParkingEntry(
                        key: ValueKey('parking-${pin.id}'),
                        pin: pin,
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }
}

class _HistoryMap extends StatelessWidget {
  const _HistoryMap({required this.pins});

  final List<SavedParkingLocation> pins;

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in pins) LatLng(p.latitude, p.longitude)];

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.cardRadius),
      child: SizedBox(
        height: 220,
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
                    point: LatLng(pin.latitude, pin.longitude),
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 36,
                      color: pin.isActive ? AppColors.cyan : AppColors.red,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black45),
                      ],
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
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

class _ParkingEntry extends ConsumerWidget {
  const _ParkingEntry({super.key, required this.pin});

  final SavedParkingLocation pin;

  String _period(String locale) {
    final start = Fmt.time(pin.timestamp, locale);
    final end = pin.endedAt;
    if (end == null) return start;
    final sameDay = DateX.dayOnly(end) == DateX.dayOnly(pin.timestamp);
    final endText = sameDay
        ? Fmt.time(end, locale)
        : '${Fmt.date(end, locale)} ${Fmt.time(end, locale)}';
    return '$start → $endText';
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
    final card = GlassCard(
      blur: false,
      accent: color,
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
                      _period(locale),
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
          if (pin.hasFix)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launch(
                      () => launcher.directionsTo(
                        lat: pin.latitude,
                        lng: pin.longitude,
                      ),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: _ButtonLabel(l10n.raw('parkingGoThere')),
                    style: _buttonStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launch(
                      () => launcher.openMap(
                        lat: pin.latitude,
                        lng: pin.longitude,
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: _ButtonLabel(l10n.raw('parkingShowOnMap')),
                    style: _buttonStyle,
                  ),
                ),
              ],
            )
          else
            Text(
              l10n.raw('parkingNoFix'),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
        ],
      ),
    );

    // The spot the car is in now is ended from the dashboard card, not
    // swiped away from its own history.
    if (pin.isActive) return card;

    return Dismissible(
      key: ValueKey('dismiss-${pin.id}'),
      direction: DismissDirection.endToStart,
      background: SwipeDeleteBackground(label: l10n.delete),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) {
        // The container, not `ref`: this row is gone by the time undo is tapped.
        final container = ProviderScope.containerOf(context, listen: false);
        final controller = container.read(parkingControllerProvider.notifier);
        controller.delete(pin.id);
        showUndoSnack(context, onUndo: () => controller.restore(pin));
      },
      child: card,
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
