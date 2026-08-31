import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/location_picker_screen.dart';
import '../../domain/entities/dealer.dart';
import '../providers/dealer_providers.dart';

/// Add a workshop of your own to the directory.
///
/// Coordinates are optional: leave them blank and navigation falls back to a
/// name + address search, which is usually what a user has to hand anyway.
class WorkshopFormSheet extends ConsumerStatefulWidget {
  const WorkshopFormSheet({super.key, this.existing});

  final Dealer? existing;

  static Future<void> show(BuildContext context, {Dealer? existing}) =>
      showAppSheet(
        context: context,
        builder: (_) => WorkshopFormSheet(existing: existing),
      );

  @override
  ConsumerState<WorkshopFormSheet> createState() => _WorkshopFormSheetState();
}

class _WorkshopFormSheetState extends ConsumerState<WorkshopFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _hours;
  late final TextEditingController _notes;

  late DealerKind _kind;

  /// **Chosen on a map, never typed.** Two decimal fields are the one part of
  /// this form nobody can fill honestly: the driver has no idea what the
  /// numbers are, and in Egypt latitude and longitude ranges overlap — 22-32
  /// north against 25-35 east — so a transposed pair still looks valid, passes
  /// any range check, and drops the pin somewhere else in the country. The
  /// picker removes the ordering as a concept the user can get wrong.
  PickedLocation? _location;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _name = TextEditingController(text: d?.name ?? '');
    _city = TextEditingController(text: d?.city ?? '');
    _address = TextEditingController(text: d?.address ?? '');
    _phone = TextEditingController(text: d?.phone ?? '');
    _hours = TextEditingController(text: d?.openingHours ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _location = (d?.latitude != null && d?.longitude != null)
        ? (latitude: d!.latitude!, longitude: d.longitude!)
        : null;
    _kind = d?.kind ?? DealerKind.independentWorkshop;
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _address, _phone, _hours, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(dealerControllerProvider.notifier);
    final lat = _location?.latitude;
    final lng = _location?.longitude;

    final bool ok;
    if (_isEdit) {
      ok = await controller.save(
        widget.existing!.copyWith(
          name: _name.text.trim(),
          city: _city.text.trim(),
          kind: _kind,
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          openingHours: _hours.text.trim(),
          latitude: lat,
          longitude: lng,
          notes: _notes.text.trim(),
        ),
      );
    } else {
      ok = await controller.add(
        name: _name.text.trim(),
        city: _city.text.trim(),
        kind: _kind,
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        openingHours: _hours.text.trim(),
        latitude: lat,
        longitude: lng,
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

    return AppSheetScaffold(
      formKey: _formKey,
      title: _isEdit ? l10n.raw('editWorkshop') : l10n.addWorkshop,
      submitLabel: _isEdit ? l10n.saveChanges : l10n.save,
      icon: AppIcons.workshops,
      isSubmitting: ref.watch(dealerControllerProvider).isLoading,
      onSubmit: _submit,
      children: [
        AppChoiceRow<DealerKind>(
          label: l10n.category,
          values: DealerKind.values,
          selected: _kind,
          labelOf: (k) => l10n.raw(k.l10nKey),
          onChanged: (k) => setState(() => _kind = k),
        ),
        AppTextField(
          controller: _name,
          label: l10n.workshop,
          required: true,
          prefixIcon: Icons.storefront_outlined,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _city,
                label: l10n.city,
                required: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _phone,
                label: l10n.phone,
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        AppTextField(
          controller: _address,
          label: l10n.address,
          prefixIcon: Icons.place_outlined,
        ),
        AppTextField(
          controller: _hours,
          label: l10n.openingHours,
          prefixIcon: Icons.schedule_rounded,
        ),
        _LocationField(
          value: _location,
          onPick: () async {
            final picked = await LocationPickerScreen.show(
              context,
              initial: _location,
            );
            if (picked != null) setState(() => _location = picked);
          },
          onClear: () => setState(() => _location = null),
        ),
        AppTextField(controller: _notes, label: l10n.notes, maxLines: 2),
      ],
    );
  }
}

/// The map pin, as a row rather than a pair of number fields.
///
/// States plainly what the pin is *for*. The old caption sat under two
/// unfillable boxes saying only "open in maps", which named a button somewhere
/// else rather than telling the driver that leaving this blank is what removes
/// that button from the card.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final PickedLocation? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      picked == null
                          ? Icons.add_location_alt_outlined
                          : Icons.place_rounded,
                      size: 20,
                      color: picked == null
                          ? context.tokens.textSecondary
                          : AppColors.cyan,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: picked == null
                          ? Text(
                              l10n.raw('pickLocationAction'),
                              style: context.text.bodyMedium?.copyWith(
                                color: context.tokens.textSecondary,
                              ),
                            )
                          : Text(
                              // Forced left-to-right: a coordinate pair
                              // reversed by an RTL layout reads as a different
                              // place entirely.
                              '${picked.latitude.toStringAsFixed(6)}, '
                              '${picked.longitude.toStringAsFixed(6)}',
                              textDirection: TextDirection.ltr,
                              style: context.text.bodyMedium,
                            ),
                    ),
                    if (picked != null)
                      IconButton(
                        tooltip: l10n.delete,
                        onPressed: onClear,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.tokens.textSecondary,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.tokens.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.raw('pickLocationHint'),
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
