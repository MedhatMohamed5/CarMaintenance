import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/widgets/account_card.dart';
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

/// Preferences, the vehicle list, and transfer.
///
/// **Every section watches its own providers and nothing else.** This build
/// used to read seven of them — theme, locale, notifications, metric, backend,
/// vehicles, transfer state — so flipping one switch rebuilt the whole screen:
/// eight cards, every vehicle row, and all five fuel-price fields. Split into
/// leaves, a theme change now rebuilds the theme card alone.
///
/// The children list is `const`, which makes that split pay off a second time.
/// [KeyboardAwareScrollPadding] re-runs its builder on every frame of the
/// keyboard animation, and a const list is canonicalised — the same instances
/// come back each frame, so `Element.update` short-circuits every section and
/// only the padding actually changes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Opaque, unlike the other in-shell screens. This one resizes for the
      // keyboard, and the strip the resize vacates has to be painted by
      // *something* — leaving it transparent is what showed as a black band
      // under the fields. The colour is the theme's own ground, so it is
      // indistinguishable from the ambient backdrop above it.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(context.l10n.settings)),
      // Resizing here is correct and deliberate: it is what lets the focused
      // field scroll itself into view. The shell above holds still
      // (`resizeToAvoidBottomInset: false`) so the inset is only ever
      // subtracted once.
      body: KeyboardAwareScrollPadding(
        builder: (context, padding) => ListView(
          padding: padding,
          // Dismiss on a drag: the fuel-price fields sit at the end of a long
          // list, and reaching for anything above them meant tapping away first.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: const [
            _SettingsSection(order: 0, child: AccountCard()),
            _SettingsSection(order: 1, child: _ThemeCard()),
            _SettingsSection(order: 2, child: _LanguageCard()),
            _SettingsSection(order: 3, child: _NotificationsCard()),
            _SettingsSection(order: 4, child: _MetricCard()),
            _SettingsSection(order: 5, child: _FuelPricesCard()),
            _SettingsSection(order: 6, child: _VehiclesCard()),
            _SettingsSection(order: 7, last: true, child: _TransferCard()),
          ],
        ),
      ),
    );
  }
}

/// One rung of the settings entrance ladder.
///
/// The screen had no entrance at all, which is why it arrived flat next to
/// `/forecast`. Same ladder as the dashboard, for the same reason: the entrance
/// belongs to the position, so it is declared once here in reading order rather
/// than eight times inside the sections.
///
/// Keyed on the position, so the played state belongs to the slot — a provider
/// emission reuses the element and nothing re-animates.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.order,
    required this.child,
    this.last = false,
  });

  final int order;
  final Widget child;

  /// Suppresses the trailing gap; the scroll gutter takes over from there.
  final bool last;

  /// Short enough that the last rung lands well inside a second: eight
  /// sections at 40 ms tops out at 280 ms before its own fade.
  static const Duration _step = Duration(milliseconds: 40);

  @override
  Widget build(BuildContext context) => EntranceAnimation(
    key: ValueKey('settings-section-$order'),
    delay: _step * order,
    duration: const Duration(milliseconds: 260),
    child: Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 22),
      child: child,
    ),
  );
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ],
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notificationsOn = ref.watch(notificationsEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

/// L/100 km is the default; km/L is the optional secondary unit. The choice is
/// presentation only — the engine always computes L/100 km.
class _MetricCard extends ConsumerWidget {
  const _MetricCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

/// Default price per fuel type, used to prefill a new fill-up.
///
/// A plain [StatelessWidget] on purpose: each field owns its controller and
/// persists on change, so nothing here needs to watch the price provider.
/// Watching it would rebuild all five fields on every keystroke in any one.
class _FuelPricesCard extends StatelessWidget {
  const _FuelPricesCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: context.l10n.defaultFuelPrice,
          icon: AppIcons.fuel,
        ),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              // Keyed on the type so adding a fuel type — octane 80 and
              // natural gas both arrived after this section was written —
              // cannot hand one field's controller to another's row.
              for (final type in FuelType.values)
                _DefaultFuelPriceField(key: ValueKey(type), type: type),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehiclesCard extends ConsumerWidget {
  const _VehiclesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vehicles = ref.watch(vehiclesProvider);
    // One transfer at a time: both directions write through the same
    // repositories, so a second run mid-import would interleave with it.
    final transferring = ref.watch(vehicleTransferControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.myVehicles,
          icon: AppIcons.vehicle,
          actionLabel: l10n.add,
          onAction: () => VehicleFormSheet.show(context),
        ),
        for (final v in vehicles)
          Padding(
            key: ValueKey('settings-vehicle-${v.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              accent: VehiclePaint.accentFor(v.colorValue),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      ],
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
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final transferring = ref.watch(vehicleTransferControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
  const _DefaultFuelPriceField({super.key, required this.type});

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
