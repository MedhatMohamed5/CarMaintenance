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
import '../../../dealers/presentation/providers/dealer_providers.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/consumable_part.dart';
import '../../domain/entities/maintenance_record.dart';
import '../../domain/entities/service_milestone.dart';
import '../../domain/entities/upcoming_service.dart';
import '../providers/maintenance_providers.dart';

/// Log a completed service.
///
/// Can be opened blank, or pre-filled from a scheduled milestone — in which
/// case the milestone's replace-list arrives pre-ticked, so closing out the
/// 40,000 km service is a two-tap job rather than a data-entry exercise.
class ServiceFormSheet extends ConsumerStatefulWidget {
  const ServiceFormSheet({super.key, this.fromMilestone, this.existing});

  final UpcomingService? fromMilestone;
  final MaintenanceRecord? existing;

  static Future<void> show(
    BuildContext context, {
    UpcomingService? fromMilestone,
    MaintenanceRecord? existing,
  }) => showAppSheet(
    context: context,
    builder: (_) =>
        ServiceFormSheet(fromMilestone: fromMilestone, existing: existing),
  );

  @override
  ConsumerState<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _odometer;
  late final TextEditingController _cost;
  late final TextEditingController _workshop;
  late final TextEditingController _notes;

  late DateTime _date;
  late ServiceTier _tier;
  late Set<ConsumablePart> _replaced;
  late Set<String> _inspected;
  int? _milestoneOdometer;

  /// The record this sheet is editing: an explicit one, or the log that
  /// already closes the selected milestone. Matching the phase here is what
  /// makes re-logging an update rather than a duplicate.
  MaintenanceRecord? _target;

  bool get _isEdit => _target != null;

  @override
  void initState() {
    super.initState();
    final record = widget.existing ?? widget.fromMilestone?.completedRecord;
    _target = record;
    final milestone = widget.fromMilestone?.milestone;
    final vehicle = ref.read(selectedVehicleProvider);

    _date = record?.date ?? DateTime.now();
    _tier = record?.tier ?? milestone?.tier ?? ServiceTier.minor;
    _replaced = {...?record?.replacedParts, ...?milestone?.replaceParts};
    _inspected = {...?record?.inspectedKeys, ...?milestone?.inspectKeys};
    _milestoneOdometer = record?.milestoneOdometer ?? milestone?.targetOdometer;

    _title = TextEditingController(text: record?.title ?? '');
    _odometer = TextEditingController(
      text:
          (record?.odometer ??
                  milestone?.targetOdometer ??
                  vehicle?.currentOdometer ??
                  '')
              .toString(),
    );
    _cost = TextEditingController(
      text: record == null || record.cost == 0
          ? ''
          : record.cost.toStringAsFixed(0),
    );
    _workshop = TextEditingController(text: record?.workshopName ?? '');
    _notes = TextEditingController(text: record?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _odometer, _cost, _workshop, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = context.l10n;
    final controller = ref.read(maintenanceControllerProvider.notifier);
    final title = _title.text.trim().isEmpty
        ? l10n.raw(_tier.l10nKey)
        : _title.text.trim();
    final odometer = int.tryParse(_odometer.text.trim()) ?? 0;
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    final bool ok;
    if (_isEdit) {
      ok = await controller.save(
        _target!.copyWith(
          date: _date,
          odometer: odometer,
          title: title,
          tier: _tier,
          replacedParts: _replaced.toList(),
          inspectedKeys: _inspected.toList(),
          cost: cost,
          workshopName: _workshop.text.trim(),
          notes: _notes.text.trim(),
          milestoneOdometer: _milestoneOdometer,
        ),
      );
    } else {
      ok = await controller.logService(
        date: _date,
        odometer: odometer,
        title: title,
        tier: _tier,
        replacedParts: _replaced.toList(),
        inspectedKeys: _inspected.toList(),
        cost: cost,
        workshopName: _workshop.text.trim(),
        notes: _notes.text.trim(),
        milestoneOdometer: _milestoneOdometer,
      );
    }

    if (!mounted) return;
    if (!ok) {
      showAppSnack(
        context,
        l10n.somethingWentWrong,
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    Navigator.of(context).pop();
    showAppSnack(context, l10n.raw('saved'), icon: Icons.check_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicle = ref.watch(selectedVehicleProvider);
    final accent = Color(_tier.colorValue);
    final workshops = ref.watch(dealersProvider);

    return AppSheetScaffold(
      formKey: _formKey,
      title: _isEdit ? l10n.raw('editService') : l10n.logService,
      submitLabel: _isEdit ? l10n.saveChanges : l10n.save,
      icon: AppIcons.serviceLog,
      accent: accent,
      isSubmitting: ref.watch(maintenanceControllerProvider).isLoading,
      onSubmit: _submit,
      children: [
        AppChoiceRow<ServiceTier>(
          label: l10n.serviceType,
          values: ServiceTier.values,
          selected: _tier,
          labelOf: (t) => l10n.raw(t.l10nKey),
          colorOf: (t) => Color(t.colorValue),
          onChanged: (t) => setState(() => _tier = t),
        ),
        if (_milestoneOdometer != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PillChip(
              label: l10n.fmt('serviceAt', {
                'n': Fmt.int0(_milestoneOdometer!, locale),
              }),
              color: accent,
              selected: true,
              icon: AppIcons.schedule,
            ),
          ),
        AppTextField(
          controller: _title,
          label: l10n.title,
          hint: l10n.raw(_tier.l10nKey),
        ),
        AppDateField(
          label: l10n.date,
          value: _date,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d ?? _date),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _odometer,
                label: l10n.currentOdometer,
                required: true,
                numeric: true,
                suffix: l10n.km,
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null) return l10n.invalidNumber;
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _cost,
                label: l10n.cost,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.currency,
              ),
            ),
          ],
        ),
        // Suggests centres already in the directory but stays free text, so an
        // unlisted workshop is never a dead end.
        Autocomplete<String>(
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return workshops
                .map((d) => d.name)
                .where((n) => n.toLowerCase().contains(q));
          },
          onSelected: (v) => _workshop.text = v,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            controller.text = _workshop.text;
            return AppTextField(
              controller: controller,
              label: l10n.workshop,
              prefixIcon: Icons.storefront_outlined,
              onChanged: (v) => _workshop.text = v,
            );
          },
        ),
        _PartsPicker(
          selected: _replaced,
          onToggle: (part) => setState(() {
            _replaced.contains(part)
                ? _replaced.remove(part)
                : _replaced.add(part);
          }),
        ),
        if (widget.fromMilestone != null)
          _InspectionPicker(
            keys: widget.fromMilestone!.milestone.inspectKeys,
            selected: _inspected,
            onToggle: (key) => setState(() {
              _inspected.contains(key)
                  ? _inspected.remove(key)
                  : _inspected.add(key);
            }),
          ),
        AppTextField(controller: _notes, label: l10n.notes, maxLines: 2),
        if (vehicle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.raw('chooseParts'),
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Multi-select over the parts catalogue. Ticking a part is what resets its
/// health bar once the service is saved.
class _PartsPicker extends StatelessWidget {
  const _PartsPicker({required this.selected, required this.onToggle});

  final Set<ConsumablePart> selected;
  final ValueChanged<ConsumablePart> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_rounded, size: 16, color: AppColors.green),
              const SizedBox(width: 6),
              Text(
                '${l10n.replaceAndChange}:',
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final part in ConsumablePart.values)
                PillChip(
                  label: l10n.raw(part.l10nKey),
                  color: Color(part.colorValue),
                  selected: selected.contains(part),
                  icon: selected.contains(part)
                      ? Icons.check_circle_rounded
                      : AppIcons.of(part.iconKey),
                  onTap: () => onToggle(part),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InspectionPicker extends StatelessWidget {
  const _InspectionPicker({
    required this.keys,
    required this.selected,
    required this.onToggle,
  });

  final List<String> keys;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 16,
                color: AppColors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.inspectAndReview}:',
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in keys)
                PillChip(
                  label: l10n.raw(key),
                  color: AppColors.amber,
                  selected: selected.contains(key),
                  onTap: () => onToggle(key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
