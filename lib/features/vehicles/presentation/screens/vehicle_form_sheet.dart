import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_catalog.dart';
import '../../domain/entities/vehicle_paint.dart';
import '../providers/vehicle_catalog_providers.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/vehicle_catalog_field.dart';
import '../widgets/vehicle_photo_field.dart';
import '../../../../core/widgets/app_icons.dart';

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
  late final TextEditingController _customMake;
  late final TextEditingController _customModel;
  late final TextEditingController _odometer;
  late final TextEditingController _nickname;
  late final TextEditingController _plate;
  late final TextEditingController _tank;
  String? _selectedMake;
  String? _selectedModel;

  /// The baseline the vehicle joined the app at. Every accumulative metric is
  /// measured from it, so it is editable in both modes: a car entered at the
  /// wrong number would otherwise report no distance for ever.
  late final TextEditingController _initialOdometer;

  late int _year;
  DateTime? _purchaseDate;
  DateTime? _licenseExpiry;
  DateTime? _insuranceExpiry;
  late int _colorValue;
  String? _imageBase64;

  bool get _isEdit => widget.existing != null;

  /// Set once the user types into the current-reading field, which releases it
  /// from mirroring the baseline.
  bool _currentTouched = false;

  int? get _initialValue => int.tryParse(_initialOdometer.text.trim());

  int? get _currentValue => int.tryParse(_odometer.text.trim());

  /// One rule for both fields: present, a whole number, not negative, and the
  /// current reading never behind the baseline. Validating the pair from either
  /// side means fixing one field clears the error on the other.
  String? _validateOdometer(
    AppLocalizations l10n,
    String? value, {
    required bool isInitial,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.required_;

    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) return l10n.invalidNumber;

    final other = isInitial ? _currentValue : _initialValue;
    if (other == null) return null;

    if (isInitial && parsed > other) return l10n.raw('initialAboveCurrent');
    if (!isInitial && parsed < other) {
      return l10n.raw('currentOdometerHint');
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _resolveCatalogSelection(v);
    _year = v?.year ?? DateTime.now().year;
    _odometer = TextEditingController(
      text: v == null ? '' : v.currentOdometer.toString(),
    );
    _initialOdometer = TextEditingController(
      text: v == null ? '' : v.initialOdometer.toString(),
    );
    // A new vehicle usually starts where it stands: typing the baseline fills
    // the current reading until the user says otherwise.
    if (v == null) {
      _initialOdometer.addListener(_mirrorInitialToCurrent);
    }
    _nickname = TextEditingController(text: v?.nickname ?? '');
    _plate = TextEditingController(text: v?.plateNumber ?? '');
    _tank = TextEditingController(
      text: v?.tankCapacityLiters?.toStringAsFixed(0) ?? '',
    );
    _purchaseDate = v?.purchaseDate;
    _licenseExpiry = v?.licenseExpiry;
    _insuranceExpiry = v?.insuranceExpiry;
    // Create mode starts on the head of the palette; edit mode keeps whatever
    // the vehicle was saved with.
    _colorValue = v?.colorValue ?? VehiclePaint.defaultPaint.colorValue;
    _imageBase64 = v?.imageBase64;
  }

  /// Maps a saved vehicle onto the catalogue, or onto "Other" plus the
  /// custom fields when the stored names are not in the list.
  void _resolveCatalogSelection(Vehicle? vehicle) {
    const catalog = VehicleCatalog();
    final make = vehicle?.make.trim() ?? '';
    final model = vehicle?.model.trim() ?? '';

    if (make.isEmpty) {
      _selectedMake = null;
      _selectedModel = null;
      _customMake = TextEditingController();
      _customModel = TextEditingController();
      return;
    }

    if (catalog.hasMake(make)) {
      _selectedMake = make;
      _customMake = TextEditingController();
      if (catalog.hasModel(make, model)) {
        _selectedModel = model;
        _customModel = TextEditingController();
      } else {
        _selectedModel = VehicleCatalog.otherKey;
        _customModel = TextEditingController(text: model);
      }
      return;
    }

    _selectedMake = VehicleCatalog.otherKey;
    _customMake = TextEditingController(text: make);
    _selectedModel = VehicleCatalog.otherKey;
    _customModel = TextEditingController(text: model);
  }

  String get _resolvedMake => _selectedMake == VehicleCatalog.otherKey
      ? _customMake.text.trim()
      : (_selectedMake ?? '');

  String get _resolvedModel => _selectedModel == VehicleCatalog.otherKey
      ? _customModel.text.trim()
      : (_selectedModel ?? '');

  void _onMakeChanged(String make) {
    final catalog = ref.read(vehicleCatalogProvider);
    setState(() {
      _selectedMake = make;
      if (make == VehicleCatalog.otherKey) {
        _selectedModel = VehicleCatalog.otherKey;
        return;
      }
      final model = _selectedModel;
      if (model == null ||
          model == VehicleCatalog.otherKey ||
          !catalog.hasModel(make, model)) {
        _selectedModel = null;
        _customModel.clear();
      }
    });
  }

  /// Keeps the current reading in step with the baseline while adding a
  /// vehicle, and stops the moment the user edits the current field itself.
  void _mirrorInitialToCurrent() {
    if (_isEdit || _currentTouched) return;
    _odometer.text = _initialOdometer.text;
  }

  @override
  void dispose() {
    _initialOdometer.removeListener(_mirrorInitialToCurrent);
    for (final c in [
      _customMake,
      _customModel,
      _odometer,
      _initialOdometer,
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
    // The validators have already proved both are present, non-negative and
    // ordered, so the fallbacks here are only for the impossible case.
    final initial = _initialValue ?? 0;
    final current = _currentValue ?? initial;

    final bool ok;
    if (_isEdit) {
      final v = widget.existing!;
      ok = await controller.save(
        v.copyWith(
          make: _resolvedMake,
          model: _resolvedModel,
          year: _year,
          initialOdometer: initial,
          currentOdometer: current,
          nickname: _nickname.text.trim(),
          plateNumber: _plate.text.trim(),
          purchaseDate: _purchaseDate,
          licenseExpiry: _licenseExpiry,
          insuranceExpiry: _insuranceExpiry,
          clearLicenseExpiry: _licenseExpiry == null,
          clearInsuranceExpiry: _insuranceExpiry == null,
          tankCapacityLiters: double.tryParse(_tank.text.trim()),
          colorValue: _colorValue,
          imageBase64: _imageBase64,
          clearImage: _imageBase64 == null,
          odometerUpdatedAt: DateTime.now(),
        ),
      );
    } else {
      ok = await controller.add(
        make: _resolvedMake,
        model: _resolvedModel,
        year: _year,
        initialOdometer: initial,
        currentOdometer: current,
        nickname: _nickname.text.trim(),
        plateNumber: _plate.text.trim(),
        purchaseDate: _purchaseDate,
        licenseExpiry: _licenseExpiry,
        insuranceExpiry: _insuranceExpiry,
        tankCapacityLiters: double.tryParse(_tank.text.trim()),
        colorValue: _colorValue,
        imageBase64: _imageBase64,
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
      submitLabel: _isEdit ? l10n.saveChanges : l10n.save,
      icon: Icons.directions_car_filled_rounded,
      accent: VehiclePaint.accentFor(_colorValue),
      isSubmitting: isSubmitting,
      onSubmit: _submit,
      children: [
        VehiclePhotoField(
          imageBase64: _imageBase64,
          accent: VehiclePaint.accentFor(_colorValue),
          onChanged: (value) => setState(() => _imageBase64 = value),
        ),
        _MakeModelFields(
          selectedMake: _selectedMake,
          selectedModel: _selectedModel,
          customMake: _customMake,
          customModel: _customModel,
          onMakeChanged: _onMakeChanged,
          onModelChanged: (model) => setState(() => _selectedModel = model),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  onChanged: (value) => setState(() => _year = value ?? _year),
                ),
              ),
            ),
          ],
        ),
        // Two readings, always. The baseline is what every per-kilometre figure
        // is measured from; the current reading is what moves.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _initialOdometer,
                label: l10n.initialOdometer,
                required: true,
                numeric: true,
                suffix: l10n.km,
                prefixIcon: Icons.flag_outlined,
                validator: (value) =>
                    _validateOdometer(l10n, value, isInitial: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _odometer,
                label: l10n.vehicleCurrentOdometer,
                required: true,
                numeric: true,
                suffix: l10n.km,
                prefixIcon: AppIcons.odometer,
                onChanged: (_) => _currentTouched = true,
                validator: (value) =>
                    _validateOdometer(l10n, value, isInitial: false),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 12),
          child: Text(
            l10n.raw('initialOdometerHint'),
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        AppTextField(controller: _nickname, label: l10n.nickname),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(controller: _plate, label: l10n.plateNumber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _tank,
                label: l10n.tankCapacity,
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
                onTap: () => setState(() => _colorValue = paint.colorValue),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Make and model pickers, isolated so a year or colour tap does not
/// re-filter the catalogue. The lists themselves live in Riverpod and are
/// never copied into this widget's state.
class _MakeModelFields extends ConsumerWidget {
  const _MakeModelFields({
    required this.selectedMake,
    required this.selectedModel,
    required this.customMake,
    required this.customModel,
    required this.onMakeChanged,
    required this.onModelChanged,
  });

  final String? selectedMake;
  final String? selectedModel;
  final TextEditingController customMake;
  final TextEditingController customModel;
  final ValueChanged<String> onMakeChanged;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final makes = ref.watch(vehicleMakesProvider);
    final models = ref.watch(vehicleModelsProvider(selectedMake));
    final makeIsOther = selectedMake == VehicleCatalog.otherKey;
    final modelIsOther = selectedModel == VehicleCatalog.otherKey;
    final makePicked = selectedMake != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: VehicleCatalogField(
                label: l10n.make,
                value: selectedMake,
                options: makes,
                prefixIcon: Icons.factory_outlined,
                onChanged: onMakeChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: VehicleCatalogField(
                key: ValueKey<String>('model-${selectedMake ?? 'none'}'),
                label: l10n.model,
                value: selectedModel,
                options: models,
                enabled: makePicked,
                emptyHint: l10n.raw('selectMakeFirst'),
                prefixIcon: Icons.directions_car_outlined,
                onChanged: onModelChanged,
              ),
            ),
          ],
        ),
        if (makeIsOther)
          AppTextField(
            controller: customMake,
            label: l10n.raw('customMake'),
            required: true,
            prefixIcon: Icons.edit_outlined,
          ),
        if (modelIsOther)
          AppTextField(
            controller: customModel,
            label: l10n.raw('customModel'),
            required: true,
            prefixIcon: Icons.edit_outlined,
          ),
      ],
    );
  }
}

/// The tick drawn on a selected swatch.
///
/// Two layers: a soft disc of the opposite ink at low opacity, then the tick
/// itself in that ink. The disc guarantees separation even when the paint and
/// the ink are close in tone, which is what made the tick disappear on the
/// pale bodies.
class _Checkmark extends StatelessWidget {
  const _Checkmark({required this.paint});

  final VehiclePaint paint;

  @override
  Widget build(BuildContext context) {
    final ink = paint.onColor;

    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink.withValues(alpha: 0.16),
          border: Border.all(color: ink.withValues(alpha: 0.35)),
        ),
        child: Icon(Icons.check_rounded, size: 17, color: ink),
      ),
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
              duration: AppDurations.stateChange,
              curve: Curves.fastOutSlowIn,
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
                  color: selected ? paint.accent : paint.outline,
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
              child: selected ? _Checkmark(paint: paint) : null,
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
