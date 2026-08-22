import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
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
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _notes;

  late DealerKind _kind;

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
    _lat = TextEditingController(text: d?.latitude?.toString() ?? '');
    _lng = TextEditingController(text: d?.longitude?.toString() ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _kind = d?.kind ?? DealerKind.independentWorkshop;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _city,
      _address,
      _phone,
      _hours,
      _lat,
      _lng,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(dealerControllerProvider.notifier);
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _lat,
                label: 'Latitude',
                numeric: true,
                allowDecimal: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _lng,
                label: 'Longitude',
                numeric: true,
                allowDecimal: true,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.openInMaps,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        AppTextField(controller: _notes, label: l10n.notes, maxLines: 2),
      ],
    );
  }
}
