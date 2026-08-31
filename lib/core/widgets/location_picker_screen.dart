import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../localization/app_localizations.dart';
import '../platform/platform_providers.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// A point the driver chose, in the only coordinate system anything here uses.
///
/// WGS84 decimal degrees — what GPS reports, what OpenStreetMap renders, and
/// what Google Maps reads back. There is no conversion anywhere in this
/// feature, and a point picked on one map opens on the other unchanged.
typedef PickedLocation = ({double latitude, double longitude});

/// Full-screen map for choosing a point.
///
/// **The pin does not move; the map does.** A draggable marker is the obvious
/// design and the wrong one on a phone: the thing you are trying to place is
/// under your thumb exactly when you need to see it. A fixed crosshair over a
/// map that pans leaves the target visible the whole time, and it means the
/// answer is simply wherever the centre ended up.
///
/// **A route rather than a sheet, and that is not a style preference.** The
/// app's sheets are draggable, and a draggable sheet wrapped around a pannable
/// map fights every vertical gesture — drag up and either the map scrolls or
/// the sheet closes, with no way for the user to predict which.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  /// Opens the picker and resolves to the chosen point, or null if the driver
  /// backed out.
  static Future<PickedLocation?> show(
    BuildContext context, {
    PickedLocation? initial,
  }) => Navigator.of(context, rootNavigator: true).push<PickedLocation>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerScreen(initial: initial),
    ),
  );

  /// Where the map opens when there is nothing better to go on.
  ///
  /// Central Cairo. Not (0, 0) — that is in the Gulf of Guinea, and a driver
  /// who lands there has to pan across a continent before the map means
  /// anything.
  static const LatLng _fallbackCentre = LatLng(30.0444, 31.2357);

  /// Close enough to read street names and place a pin on the right side of a
  /// road, without being so close that finding the area takes forever.
  static const double _initialZoom = 15;

  /// OpenStreetMap's own tiles: free, no key, no billing account.
  ///
  /// **Fine here, and worth revisiting before a wide release.** OSM's tile
  /// usage policy asks that distributed apps not lean on the public servers.
  /// Swapping to a free-tier provider is this one string plus a key, which is
  /// why it is a constant rather than spread through the widget below.
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Sent as the User-Agent, which the same policy requires. The real
  /// application id, so a misbehaving build can actually be identified.
  static const String _tileUserAgent = 'com.vehiclecare.vehicle_care';

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();

  /// The crosshair's position, as a listenable rather than as widget state.
  ///
  /// **`onPositionChanged` fires on every frame of a pan.** Routing that
  /// through `setState` rebuilt this whole subtree sixty times a second — the
  /// `FlutterMap` and its tile layer included — to update one line of text. A
  /// `ValueNotifier` read by a `ValueListenableBuilder` in the footer leaves
  /// the map alone and rebuilds only the readout.
  late final ValueNotifier<LatLng> _centre;

  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _centre = ValueNotifier(
      initial == null
          ? LocationPickerScreen._fallbackCentre
          : LatLng(initial.latitude, initial.longitude),
    );
  }

  @override
  void dispose() {
    _centre.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Jumps the map to where the driver is standing.
  ///
  /// **A shortcut to a starting point, never the answer.** The workshop being
  /// added is usually somewhere else entirely; this only saves panning across
  /// a governorate first. The chosen point is still whatever the crosshair ends
  /// up over.
  Future<void> _jumpToMe() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.isSuccess) {
      showAppSnack(context, context.l10n.raw('locationUnavailable'));
      return;
    }
    _map.move(
      LatLng(result.latitude, result.longitude),
      LocationPickerScreen._initialZoom,
    );
  }

  /// Opens the current centre in Google Maps so the driver can sanity-check it
  /// against the place names they know, then come back and confirm.
  Future<void> _preview() async {
    final ok = await ref
        .read(launcherServiceProvider)
        .openMap(lat: _centre.value.latitude, lng: _centre.value.longitude);
    if (!ok && mounted) {
      showAppSnack(context, context.l10n.couldNotLaunch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.raw('pickLocationTitle')),
        actions: [
          IconButton(
            tooltip: l10n.raw('previewInMaps'),
            onPressed: _preview,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _centre.value,
                    initialZoom: LocationPickerScreen._initialZoom,
                    maxZoom: 19,
                    // Fired continuously while panning, so the readout below
                    // tracks the crosshair rather than lagging a gesture
                    // behind it.
                    onPositionChanged: (camera, _) =>
                        _centre.value = camera.center,
                    interactionOptions: const InteractionOptions(
                      // Rotation earns nothing here and is trivially triggered
                      // by accident with two fingers, leaving the driver on a
                      // tilted map with no obvious way back to north.
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: LocationPickerScreen._tileUrl,
                      userAgentPackageName: LocationPickerScreen._tileUserAgent,
                    ),
                    // Required by OpenStreetMap's licence, not decoration.
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                // Ignores pointers so every gesture reaches the map underneath.
                const IgnorePointer(child: _Crosshair()),
                if (_locating)
                  const Positioned(
                    top: 12,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<LatLng>(
            valueListenable: _centre,
            builder: (context, centre, _) => _PickerFooter(
              centre: centre,
              onUseMyLocation: _locating ? null : _jumpToMe,
              onConfirm: () => Navigator.of(
                context,
              ).pop((latitude: centre.latitude, longitude: centre.longitude)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed target the map moves under.
///
/// Drawn with its point at the exact centre of the viewport — the marker sits
/// half its height above centre so the tip, not the middle of the icon, is what
/// the coordinates describe.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  static const double _size = 44;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: _size),
    child: Icon(
      Icons.location_on,
      size: _size,
      color: AppColors.red,
      shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
    ),
  );
}

class _PickerFooter extends StatelessWidget {
  const _PickerFooter({
    required this.centre,
    required this.onUseMyLocation,
    required this.onConfirm,
  });

  final LatLng centre;
  final VoidCallback? onUseMyLocation;
  final VoidCallback onConfirm;

  /// Six decimal places is about 11 cm. Anything beyond it is noise in the
  /// stored record and in the Remote Config document.
  static String _format(double value) => value.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  size: 16,
                  color: context.tokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // Left-to-right regardless of the app's direction: a
                    // coordinate pair reversed by the layout is a different
                    // place, and in Egypt latitude and longitude ranges
                    // overlap, so the mistake looks perfectly plausible.
                    '${_format(centre.latitude)}, ${_format(centre.longitude)}',
                    textDirection: TextDirection.ltr,
                    style: context.text.labelMedium?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onUseMyLocation,
                  icon: const Icon(Icons.near_me_outlined, size: 16),
                  label: Text(l10n.raw('jumpToMyLocation')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.raw('confirmLocation')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
