import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_paint.dart';
import '../providers/vehicle_providers.dart';

/// Add or edit a vehicle. The same sheet serves both — passing [existing]
/// switches it to edit mode, which keeps validation and layout in one place.
const int _minYear = 1950;
const int _maxYear = 2030;

class VehicleFormSheet extends ConsumerStatefulWidget {
  const VehicleFormSheet({super.key, this.existing});

  final Vehicle? existing;

  static Future<void> show(BuildContext context, {Vehicle? existing}) =>
      showAppSheet(
        context: context,
        builder: (_) => VehicleFormSheet(existing: existing),
      );

  @override
  ConsumerState<VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _odometer;
  late final TextEditingController _nickname;
  late final TextEditingController _plate;
  late final TextEditingController _tank;

  late int _year;
  DateTime? _purchaseDate;
  DateTime? _licenseExpiry;
  DateTime? _insuranceExpiry;
  late int _colorValue;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = v?.year ?? DateTime.now().year;
    _odometer = TextEditingController(
      text: v == null ? '' : v.currentOdometer.toString(),
    );
    _nickname = TextEditingController(text: v?.nickname ?? '');
    _plate = TextEditingController(text: v?.plateNumber ?? '');
    _tank = TextEditingController(
      text: v?.tankCapacityLiters?.toStringAsFixed(0) ?? '',
    );
    _purchaseDate = v?.purchaseDate;
    _licenseExpiry = v?.licenseExpiry;
    _insuranceExpiry = v?.insuranceExpiry;
    _colorValue = v?.colorValue ?? VehiclePaint.silver.colorValue;
  }

  @override
  void dispose() {
    for (final c in [
      _make,
      _model,
      _odometer,
      _nickname,
      _plate,
      _tank,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(vehicleControllerProvider.notifier);
    final odometer = int.tryParse(_odometer.text.trim()) ?? 0;

    final bool ok;
    if (_isEdit) {
      final v = widget.existing!;
      ok = await controller.save(
        v.copyWith(
          make: _make.text.trim(),
          model: _model.text.trim(),
          year: _year,
          currentOdometer: odometer > v.currentOdometer
              ? odometer
              : v.currentOdometer,
          nickname: _nickname.text.trim(),
          plateNumber: _plate.text.trim(),
          purchaseDate: _purchaseDate,
          licenseExpiry: _licenseExpiry,
          insuranceExpiry: _insuranceExpiry,
          clearLicenseExpiry: _licenseExpiry == null,
          clearInsuranceExpiry: _insuranceExpiry == null,
          tankCapacityLiters: double.tryParse(_tank.text.trim()),
          colorValue: _colorValue,
          odometerUpdatedAt: DateTime.now(),
        ),
      );
    } else {
      ok = await controller.add(
        make: _make.text.trim(),
        model: _model.text.trim(),
        year: _year,
        odometer: odometer,
        nickname: _nickname.text.trim(),
        plateNumber: _plate.text.trim(),
        purchaseDate: _purchaseDate,
        licenseExpiry: _licenseExpiry,
        insuranceExpiry: _insuranceExpiry,
        tankCapacityLiters: double.tryParse(_tank.text.trim()),
        colorValue: _colorValue,
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
    final isSubmitting = ref.watch(vehicleControllerProvider).isLoading;

    return AppSheetScaffold(
      formKey: _formKey,
      title: _isEdit ? l10n.editVehicle : l10n.addVehicle,
      icon: Icons.directions_car_filled_rounded,
      accent: VehiclePaint.accentFor(_colorValue),
      isSubmitting: isSubmitting,
      onSubmit: _submit,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _make,
                label: l10n.make,
                required: true,
                hint: 'Toyota',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _model,
                label: l10n.model,
                required: true,
                hint: 'Corolla',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.year,
                    prefixIcon: const Icon(
                      Icons.event_available_rounded,
                      size: 20,
                    ),
                  ),
                  menuMaxHeight: 320,
                  items: [
                    for (var y = _maxYear; y >= _minYear; y--)
                      DropdownMenuItem(
                        value: y,
                        child: Text(
                          '$y',
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _year = value ?? _year),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _odometer,
                label: _isEdit ? l10n.currentOdometer : l10n.initialOdometer,
                required: true,
                numeric: true,
                suffix: l10n.km,
              ),
            ),
          ],
        ),
        AppTextField(controller: _nickname, label: l10n.nickname),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _plate,
                label: l10n.plateNumber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _tank,
                label: l10n.liter,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.liter,
              ),
            ),
          ],
        ),
        AppDateField(
          label: l10n.purchaseDate,
          value: _purchaseDate,
          clearable: true,
          onChanged: (d) => setState(() => _purchaseDate = d),
        ),
        AppDateField(
          label: l10n.licenseExpiry,
          value: _licenseExpiry,
          clearable: true,
          icon: Icons.description_outlined,
          onChanged: (d) => setState(() => _licenseExpiry = d),
        ),
        AppDateField(
          label: l10n.insuranceExpiry,
          value: _insuranceExpiry,
          clearable: true,
          icon: Icons.verified_user_outlined,
          onChanged: (d) => setState(() => _insuranceExpiry = d),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.raw('vehicleColor'),
          style: context.text.labelMedium?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final paint in VehiclePaint.values)
              _PaintSwatch(
                paint: paint,
                label: l10n.raw(paint.l10nKey),
                selected: paint.colorValue == _colorValue,
                onTap: () =>
                    setState(() => _colorValue = paint.colorValue),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PaintSwatch extends StatelessWidget {
  const _PaintSwatch({
    required this.paint,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final VehiclePaint paint;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.28),
                      paint.color,
                    ),
                    paint.color,
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? paint.accent
                      : context.tokens.border,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: paint.accent.withValues(alpha: selected ? 0.45 : 0),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: paint.accent,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.text.labelSmall?.copyWith(
                  color: selected
                      ? context.colors.onSurface
                      : context.tokens.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
