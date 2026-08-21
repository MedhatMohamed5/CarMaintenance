import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_type.dart';
import '../providers/fuel_providers.dart';

/// Colour and icon per fuel grade, shared by the sheet and the log list.
class FuelTypeStyle {
  const FuelTypeStyle._();

  static Color color(FuelType type) => switch (type) {
    FuelType.octane92 => AppColors.green,
    FuelType.octane95 => AppColors.cyan,
    FuelType.diesel => AppColors.amber,
  };

  static IconData icon(FuelType type) => switch (type) {
    FuelType.diesel => Icons.local_shipping_rounded,
    _ => Icons.local_gas_station_rounded,
  };
}

/// Add or edit a fill.
///
/// Litres, total cost and price-per-litre are mutually derivable, so the sheet
/// keeps the third in sync as you type any two — nobody should have to reach
/// for a calculator at the pump.
class FuelFormSheet extends ConsumerStatefulWidget {
  const FuelFormSheet({super.key, this.existing});

  final FuelLog? existing;

  static Future<void> show(BuildContext context, {FuelLog? existing}) =>
      showAppSheet(
        context: context,
        builder: (_) => FuelFormSheet(existing: existing),
      );

  @override
  ConsumerState<FuelFormSheet> createState() => _FuelFormSheetState();
}

class _FuelFormSheetState extends ConsumerState<FuelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _odometer;
  late final TextEditingController _liters;
  late final TextEditingController _cost;
  late final TextEditingController _pricePerLiter;
  late final TextEditingController _station;
  late final TextEditingController _notes;

  late DateTime _date;
  late FuelType _fuelType;
  late bool _isFullTank;

  /// Guards the price/cost/litres cross-updates from re-entering.
  bool _syncing = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final log = widget.existing;
    final vehicle = ref.read(selectedVehicleProvider);

    _odometer = TextEditingController(
      text: (log?.odometer ?? vehicle?.currentOdometer ?? '').toString(),
    );
    _liters = TextEditingController(
      text: log == null ? '' : _trim(log.liters),
    );
    _cost = TextEditingController(text: log == null ? '' : _trim(log.totalCost));
    _pricePerLiter = TextEditingController(
      text: log == null ? '' : _trim(log.pricePerLiter),
    );
    _station = TextEditingController(text: log?.stationName ?? '');
    _notes = TextEditingController(text: log?.notes ?? '');
    _date = log?.date ?? DateTime.now();
    _fuelType = log?.fuelType ?? FuelType.octane92;
    _isFullTank = log?.isFullTank ?? true;
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [
      _odometer,
      _liters,
      _cost,
      _pricePerLiter,
      _station,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onLitersChanged() {
    if (_syncing) return;
    final liters = double.tryParse(_liters.text.trim());
    final price = double.tryParse(_pricePerLiter.text.trim());
    if (liters == null || price == null) return;
    _syncing = true;
    _cost.text = _trim(liters * price);
    _syncing = false;
  }

  void _onPriceChanged() {
    if (_syncing) return;
    final liters = double.tryParse(_liters.text.trim());
    final price = double.tryParse(_pricePerLiter.text.trim());
    if (liters == null || price == null) return;
    _syncing = true;
    _cost.text = _trim(liters * price);
    _syncing = false;
  }

  void _onCostChanged() {
    if (_syncing) return;
    final cost = double.tryParse(_cost.text.trim());
    final liters = double.tryParse(_liters.text.trim());
    if (cost == null || liters == null || liters <= 0) return;
    _syncing = true;
    _pricePerLiter.text = _trim(cost / liters);
    _syncing = false;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(fuelControllerProvider.notifier);
    final odometer = int.tryParse(_odometer.text.trim()) ?? 0;
    final liters = double.tryParse(_liters.text.trim()) ?? 0;
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    final bool ok;
    if (_isEdit) {
      ok = await controller.save(
        widget.existing!.copyWith(
          date: _date,
          odometer: odometer,
          liters: liters,
          fuelType: _fuelType,
          totalCost: cost,
          isFullTank: _isFullTank,
          stationName: _station.text.trim(),
          notes: _notes.text.trim(),
        ),
      );
    } else {
      ok = await controller.addEntry(
        date: _date,
        odometer: odometer,
        liters: liters,
        fuelType: _fuelType,
        totalCost: cost,
        isFullTank: _isFullTank,
        stationName: _station.text.trim(),
        notes: _notes.text.trim(),
      );
    }

    if (!mounted) return;
    if (!ok) {
      showAppSnack(
        context,
        context.l10n.somethingWentWrong,
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    Navigator.of(context).pop();
    showAppSnack(context, context.l10n.raw('saved'), icon: Icons.check_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicle = ref.watch(selectedVehicleProvider);
    final accent = FuelTypeStyle.color(_fuelType);

    return AppSheetScaffold(
      formKey: _formKey,
      title: l10n.addFuelEntry,
      icon: AppIcons.fuel,
      accent: accent,
      isSubmitting: ref.watch(fuelControllerProvider).isLoading,
      onSubmit: _submit,
      children: [
        AppChoiceRow<FuelType>(
          label: l10n.fuelType,
          values: FuelType.values,
          selected: _fuelType,
          labelOf: (t) => l10n.raw(t.l10nKey),
          colorOf: FuelTypeStyle.color,
          iconOf: FuelTypeStyle.icon,
          onChanged: (t) => setState(() => _fuelType = t),
        ),
        AppDateField(
          label: l10n.date,
          value: _date,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d ?? _date),
        ),
        AppTextField(
          controller: _odometer,
          label: l10n.currentOdometer,
          required: true,
          numeric: true,
          suffix: l10n.km,
          prefixIcon: AppIcons.odometer,
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null) return l10n.invalidNumber;
            final current = vehicle?.currentOdometer ?? 0;
            // Only block readings *below* the current one when adding new —
            // editing an old entry legitimately sits behind it.
            if (!_isEdit && parsed < current) {
              return '${l10n.currentOdometer}: ${Fmt.int0(current, locale)}';
            }
            return null;
          },
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _liters,
                label: l10n.fuelAmount,
                required: true,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.liter,
                onChanged: (_) => _onLitersChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _pricePerLiter,
                label: l10n.pricePerLiter,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.currency,
                onChanged: (_) => _onPriceChanged(),
              ),
            ),
          ],
        ),
        AppTextField(
          controller: _cost,
          label: l10n.totalCost,
          required: true,
          numeric: true,
          allowDecimal: true,
          suffix: l10n.currency,
          onChanged: (_) => _onCostChanged(),
        ),
        // Full-tank status is what makes an entry measurable, so it gets an
        // explanation rather than a bare switch.
        SwitchListTile.adaptive(
          value: _isFullTank,
          onChanged: (v) => setState(() => _isFullTank = v),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: accent,
          title: Text(l10n.fullTank, style: context.text.titleSmall),
          subtitle: Text(
            l10n.fullTankHint,
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _station,
          label: l10n.raw('stationName'),
          prefixIcon: Icons.storefront_outlined,
        ),
        AppTextField(
          controller: _notes,
          label: l10n.notes,
          maxLines: 2,
        ),
      ],
    );
  }
}
