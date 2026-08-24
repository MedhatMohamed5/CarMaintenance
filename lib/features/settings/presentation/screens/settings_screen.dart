import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../fuel/domain/entities/fuel_metric.dart';
import '../../../fuel/domain/entities/fuel_type.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../fuel/presentation/screens/fuel_form_sheet.dart';
import '../../../fuel/presentation/widgets/fuel_metric_display.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/domain/entities/vehicle_paint.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_transfer_providers.dart';
import '../../../vehicles/presentation/screens/vehicle_form_sheet.dart';
import '../../../vehicles/presentation/widgets/vehicle_image.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final vehicles = ref.watch(vehiclesProvider);
    // One transfer at a time: both directions write through the same
    // repositories, so a second run mid-import would interleave with it.
    final transferring = ref.watch(vehicleTransferControllerProvider).isLoading;

    return Scaffold(
      // Lives inside the shell, so the ambient backdrop shows through and the
      // scroll gutter has to clear the floating navigation bar.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: context.screenPadding(),
        children: [
          SectionHeader(title: l10n.themeMode, icon: Icons.palette_outlined),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                ),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: l10n.language, icon: Icons.translate_rounded),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ar', label: Text('العربية')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {locale.languageCode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(localeProvider.notifier).set(Locale(s.first)),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: l10n.notifications,
            icon: Icons.notifications_outlined,
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile.adaptive(
              value: notificationsOn,
              onChanged: (v) =>
                  ref.read(notificationsEnabledProvider.notifier).set(v),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.notifications, style: context.text.titleSmall),
              subtitle: Text(
                l10n.raw('notifServiceTitle'),
                style: context.text.bodySmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // L/100 km is the default; km/L is the optional secondary unit. The
          // choice is presentation only — the engine always computes L/100 km.
          SectionHeader(title: l10n.displayMetric, icon: Icons.speed_rounded),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<FuelMetric>(
              segments: [
                for (final metric in FuelMetric.values)
                  ButtonSegment(value: metric, label: Text(metric.label(l10n))),
              ],
              selected: {ref.watch(fuelMetricProvider)},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(fuelMetricProvider.notifier).select(selection.first),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: l10n.defaultFuelPrice, icon: AppIcons.fuel),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [
                for (final type in FuelType.values)
                  _DefaultFuelPriceField(type: type),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: l10n.raw('dataSource'),
            icon: Icons.cloud_outlined,
          ),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<BackendMode>(
                  segments: [
                    ButtonSegment(
                      value: BackendMode.local,
                      label: Text(l10n.raw('sourceLocal')),
                      icon: const Icon(Icons.phone_android_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: BackendMode.firestore,
                      label: Text(l10n.raw('sourceCloud')),
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                    ),
                  ],
                  selected: {ref.watch(backendModeProvider)},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) async {
                    final ok = await ref
                        .read(backendModeProvider.notifier)
                        .set(selection.first);
                    if (!context.mounted || ok) return;
                    showAppSnack(
                      context,
                      l10n.raw('cloudUnavailable'),
                      icon: Icons.cloud_off_rounded,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  ref.watch(isRemoteBackendProvider)
                      ? l10n.raw('sourceCloudHint')
                      : l10n.raw('sourceLocalHint'),
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: l10n.myVehicles,
            icon: AppIcons.vehicle,
            actionLabel: l10n.add,
            onAction: () => VehicleFormSheet.show(context),
          ),
          for (final v in vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                accent: VehiclePaint.accentFor(v.colorValue),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    VehicleAvatar.of(v, size: 40, showRing: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.displayName, style: context.text.titleSmall),
                          Text(
                            v.subtitle,
                            style: context.text.labelSmall?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () =>
                          VehicleFormSheet.show(context, existing: v),
                    ),
                    IconButton(
                      tooltip: l10n.raw('exportVehicle'),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      onPressed: transferring
                          ? null
                          : () => _exportVehicle(context, ref, v),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.red,
                      ),
                      // Deleting a vehicle also removes its fuel, service and
                      // expense history, so it asks first.
                      onPressed: () async {
                        if (!await confirmDelete(context)) return;
                        await ref
                            .read(vehicleControllerProvider.notifier)
                            .remove(v.id);
                        if (!context.mounted) return;
                        showAppSnack(context, l10n.raw('deleted'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SectionHeader(
            title: l10n.raw('vehicleTransfer'),
            icon: Icons.swap_vert_rounded,
          ),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  l10n.raw('vehicleTransferHint'),
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: transferring
                      ? null
                      : () => _importVehicle(context, ref),
                  icon: transferring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.file_upload_outlined, size: 20),
                  label: Text(l10n.raw('importVehicle')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVehicle(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final l10n = context.l10n;
    final controller = ref.read(vehicleTransferControllerProvider.notifier);
    final ok = await controller.exportVehicle(vehicle);
    if (!context.mounted) return;

    if (!ok) {
      showAppSnack(
        context,
        l10n.raw('vehicleExportFailed'),
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final outcome = ref.read(vehicleTransferControllerProvider).value;
    if (outcome is! VehicleExportedOutcome) return;
    // Web hands the file to the browser's download list, so there is no path
    // to quote back.
    showAppSnack(
      context,
      outcome.file.downloaded
          ? '${l10n.raw('exportDownloaded')} · ${outcome.file.fileName}'
          : '${l10n.raw('exportSavedTo')} ${outcome.file.path}',
      icon: Icons.download_done_rounded,
    );
  }

  Future<void> _importVehicle(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final locale = ref.read(localeTagProvider);
    final controller = ref.read(vehicleTransferControllerProvider.notifier);
    final ok = await controller.importVehicle();
    if (!context.mounted) return;

    final state = ref.read(vehicleTransferControllerProvider);
    if (!ok) {
      showAppSnack(
        context,
        _importFailureMessage(l10n, state.error),
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    // Null outcome means the picker was dismissed — nothing to report.
    final outcome = state.value;
    if (outcome is! VehicleImportedOutcome) return;
    showAppSnack(
      context,
      l10n.fmt('vehicleImported', {
        'name': outcome.vehicleName,
        'n': Fmt.int0(outcome.entryCount, locale),
      }),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// Why the file was rejected, never how — a parser message is not something
  /// a driver can act on.
  String _importFailureMessage(AppLocalizations l10n, Object? error) =>
      switch (error) {
        VehicleTransferException(reason: VehicleTransferFailure.wrongFormat) =>
          l10n.raw('importWrongFormat'),
        VehicleTransferException(
          reason: VehicleTransferFailure.unsupportedVersion,
        ) =>
          l10n.raw('importUnsupportedVersion'),
        _ => l10n.raw('importFailed'),
      };
}

class _DefaultFuelPriceField extends ConsumerStatefulWidget {
  const _DefaultFuelPriceField({required this.type});

  final FuelType type;

  @override
  ConsumerState<_DefaultFuelPriceField> createState() =>
      _DefaultFuelPriceFieldState();
}

class _DefaultFuelPriceFieldState
    extends ConsumerState<_DefaultFuelPriceField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final price = ref.read(defaultFuelPriceByTypeProvider(widget.type));
    _controller = TextEditingController(
      text: price == null ? '' : _format(price),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  void _persist(String raw) {
    ref
        .read(defaultFuelPricesProvider.notifier)
        .setPrice(widget.type, double.tryParse(raw.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppTextField(
      controller: _controller,
      label: l10n.raw(widget.type.l10nKey),
      hint: l10n.defaultFuelPriceHint,
      numeric: true,
      allowDecimal: true,
      suffix: l10n.currency,
      prefixIcon: FuelTypeStyle.icon(widget.type),
      textInputAction: TextInputAction.done,
      onChanged: _persist,
    );
  }
}
