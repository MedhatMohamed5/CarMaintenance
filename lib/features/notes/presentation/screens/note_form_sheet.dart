import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/vehicle_note.dart';
import '../providers/note_providers.dart';

class NoteFormSheet extends ConsumerStatefulWidget {
  const NoteFormSheet({super.key, this.existing});

  final VehicleNote? existing;

  static Future<void> show(BuildContext context, {VehicleNote? existing}) =>
      showAppSheet(
        context: context,
        builder: (_) => NoteFormSheet(existing: existing),
      );

  @override
  ConsumerState<NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends ConsumerState<NoteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _text;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = context.l10n;
    final controller = ref.read(noteControllerProvider.notifier);

    final ok = _isEdit
        ? await controller.save(
            widget.existing!.copyWith(text: _text.text.trim()),
          )
        : await controller.add(_text.text.trim());

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

    return AppSheetScaffold(
      formKey: _formKey,
      title: _isEdit ? l10n.raw('editNote') : l10n.raw('addNote'),
      submitLabel: _isEdit ? l10n.saveChanges : l10n.save,
      icon: Icons.checklist_rounded,
      accent: AppColors.amber,
      isSubmitting: ref.watch(noteControllerProvider).isLoading,
      onSubmit: _submit,
      children: [
        AppTextField(
          controller: _text,
          label: l10n.notes,
          hint: l10n.raw('noteHint'),
          required: true,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
