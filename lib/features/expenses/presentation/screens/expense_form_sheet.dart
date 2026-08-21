import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key, this.existing});

  final Expense? existing;

  static Future<void> show(BuildContext context, {Expense? existing}) =>
      showAppSheet(
        context: context,
        builder: (_) => ExpenseFormSheet(existing: existing),
      );

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _odometer;
  late final TextEditingController _notes;

  late DateTime _date;
  late ExpenseCategory _category;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final vehicle = ref.read(selectedVehicleProvider);

    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(0),
    );
    _odometer = TextEditingController(
      text: (e?.odometer ?? vehicle?.currentOdometer ?? '').toString(),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? ExpenseCategory.repair;
  }

  @override
  void dispose() {
    for (final c in [_title, _amount, _odometer, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = context.l10n;
    final controller = ref.read(expenseControllerProvider.notifier);
    final title = _title.text.trim().isEmpty
        ? l10n.raw(_category.l10nKey)
        : _title.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final odometer = int.tryParse(_odometer.text.trim());

    final bool ok;
    if (_isEdit) {
      ok = await controller.save(
        widget.existing!.copyWith(
          date: _date,
          title: title,
          amount: amount,
          category: _category,
          odometer: odometer,
          notes: _notes.text.trim(),
        ),
      );
    } else {
      ok = await controller.add(
        date: _date,
        title: title,
        amount: amount,
        category: _category,
        odometer: odometer,
        notes: _notes.text.trim(),
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
    final accent = Color(_category.colorValue);

    return AppSheetScaffold(
      formKey: _formKey,
      title: l10n.addExpense,
      icon: AppIcons.expenses,
      accent: accent,
      isSubmitting: ref.watch(expenseControllerProvider).isLoading,
      onSubmit: _submit,
      children: [
        AppChoiceRow<ExpenseCategory>(
          label: l10n.category,
          values: ExpenseCategory.values,
          selected: _category,
          labelOf: (c) => l10n.raw(c.l10nKey),
          colorOf: (c) => Color(c.colorValue),
          iconOf: (c) => AppIcons.of(c.iconKey),
          onChanged: (c) => setState(() => _category = c),
        ),
        AppTextField(
          controller: _title,
          label: l10n.title,
          hint: l10n.raw(_category.l10nKey),
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _amount,
                label: l10n.amount,
                required: true,
                numeric: true,
                allowDecimal: true,
                suffix: l10n.currency,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _odometer,
                label: l10n.currentOdometer,
                numeric: true,
                suffix: l10n.km,
              ),
            ),
          ],
        ),
        AppDateField(
          label: l10n.date,
          value: _date,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d ?? _date),
        ),
        AppTextField(controller: _notes, label: l10n.notes, maxLines: 2),
      ],
    );
  }
}
