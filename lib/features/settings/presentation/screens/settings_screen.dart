import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../fuel/domain/entities/fuel_metric.dart';
import '../../../fuel/presentation/providers/fuel_providers.dart';
import '../../../fuel/presentation/widgets/fuel_metric_display.dart';
import '../../../vehicles/domain/entities/vehicle_paint.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
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
        ],
      ),
    );
  }
}
