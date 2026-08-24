import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/fuel_log.dart';
import '../../domain/entities/fuel_type.dart';
import '../../domain/usecases/derive_fuel_amounts.dart';
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
/// Volume, price per litre and total cost are one triangle: type any two and
/// the third fills itself in, in either direction. Nobody should have to reach
/// for a calculator at the pump, and nobody should have to fill the tank to
/// the brim just to make the entry count.
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

  /// One node per derivable field. A field that holds focus is one the user is
  /// typing into, and is never written to by the auto-fill.
  final _litersFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _costFocus = FocusNode();

  late DateTime _date;
  late FuelType _fuelType;
  late bool _isFullTank;

  /// Re-entrancy latch. Writing to a controller fires its listeners, so
  /// without this an auto-filled value would immediately try to auto-fill the
  /// field that produced it.
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
    _fuelType = log?.fuelType ?? FuelType.octane92;
    _liters = TextEditingController(text: log == null ? '' : _trim(log.liters));
    _cost = TextEditingController(
      text: log == null ? '' : _trim(log.totalCost),
    );
    _pricePerLiter = TextEditingController(
      text: log != null
          ? _trim(log.pricePerLiter)
          : _trimOrEmpty(ref.read(defaultFuelPriceByTypeProvider(_fuelType))),
    );
    _station = TextEditingController(text: log?.stationName ?? '');
    _notes = TextEditingController(text: log?.notes ?? '');
    _date = log?.date ?? DateTime.now();
    _isFullTank = log?.isFullTank ?? true;
  }

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
    for (final f in [_litersFocus, _priceFocus, _costFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String _trimOrEmpty(double? v) => v == null || v <= 0 ? '' : _trim(v);

  static double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim());

  TextEditingController _controllerFor(FuelAmountField field) =>
      switch (field) {
        FuelAmountField.liters => _liters,
        FuelAmountField.pricePerLiter => _pricePerLiter,
        FuelAmountField.totalCost => _cost,
      };

  FocusNode _focusOf(FuelAmountField field) => switch (field) {
    FuelAmountField.liters => _litersFocus,
    FuelAmountField.pricePerLiter => _priceFocus,
    FuelAmountField.totalCost => _costFocus,
  };

  /// Recomputes the two fields the user is not editing.
  ///
  /// Guarded three ways: the latch blocks re-entry, the edited field is
  /// excluded by construction, and a focused field is left alone even if the
  /// matrix would have resolved it, so a value can never be yanked out from
  /// under the caret.
  void _sync(FuelAmountField edited) {
    if (_syncing) return;

    final before = FuelAmounts(
      liters: _parse(_liters),
      pricePerLiter: _parse(_pricePerLiter),
      totalCost: _parse(_cost),
    );
    final after = ref.read(deriveFuelAmountsProvider)(
      input: before,
      edited: edited,
    );

    _syncing = true;
    try {
      for (final field in FuelAmountField.values) {
        if (field == edited) continue;
        if (_focusOf(field).hasFocus) continue;

        final value = after[field];
        if (value == null || value == before[field]) continue;

        final controller = _controllerFor(field);
        final text = _trim(value);
        if (controller.text == text) continue;
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } finally {
      _syncing = false;
    }
  }

  void _onFuelTypeChanged(FuelType type) {
    setState(() => _fuelType = type);
    _applyDefaultPriceFor(type);
  }

  /// Loads the Settings rate for [type] and rebuilds the triangle from it.
  ///
  /// An unset grade clears the unit price first so a 92 rate cannot stick to
  /// diesel; litres + cost then recover a derived price when both are known.
  void _applyDefaultPriceFor(FuelType type) {
    final text = _trimOrEmpty(ref.read(defaultFuelPriceByTypeProvider(type)));
    _syncing = true;
    try {
      if (_pricePerLiter.text != text) {
        _pricePerLiter.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    } finally {
      _syncing = false;
    }
    _sync(
      text.isEmpty ? FuelAmountField.liters : FuelAmountField.pricePerLiter,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(fuelControllerProvider.notifier);
    final odometer = int.tryParse(_odometer.text.trim()) ?? 0;
    final liters = _parse(_liters) ?? 0;
    final cost = _parse(_cost) ?? 0;
    final station = _station.text.trim();
    final notes = _notes.text.trim();

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
          stationName: station,
          notes: notes,
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
        stationName: station,
        notes: notes,
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
    final accent = FuelTypeStyle.color(_fuelType);

    return AppSheetScaffold(
      formKey: _formKey,
      title: _isEdit ? l10n.raw('editFuelEntry') : l10n.addFuelEntry,
      submitLabel: _isEdit ? l10n.saveChanges : l10n.save,
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
          onChanged: _onFuelTypeChanged,
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
          // Historical fills are legitimate: a back-dated entry sits behind the
          // current reading by definition. Only the number itself is validated.
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null) return l10n.invalidNumber;
            if (parsed < 0) return l10n.invalidNumber;
            return null;
          },
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _liters,
                focusNode: _litersFocus,
                label: l10n.fuelAmount,
                required: true,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.liter,
                onChanged: (_) => _sync(FuelAmountField.liters),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _pricePerLiter,
                focusNode: _priceFocus,
                label: l10n.pricePerLiter,
                hint: l10n.defaultFuelPriceHint,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.currency,
                onChanged: (_) => _sync(FuelAmountField.pricePerLiter),
              ),
            ),
          ],
        ),
        AppTextField(
          controller: _cost,
          focusNode: _costFocus,
          label: l10n.totalCost,
          required: true,
          numeric: true,
          allowDecimal: true,
          suffix: l10n.currency,
          onChanged: (_) => _sync(FuelAmountField.totalCost),
        ),
        // Descriptive only: the engine measures partial fills too. The switch
        // stays because the user knows the difference and the log list shows
        // it, but nothing is discarded either way.
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
        AppTextField(controller: _notes, label: l10n.notes, maxLines: 2),
      ],
    );
  }
}
