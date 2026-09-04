import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// Standard modal bottom sheet: rounded, scrollable, keyboard-aware and
/// capped at 92% of the screen so the sheet never swallows the whole view.
/// Opens a sheet on the root navigator, with the caller's provider container
/// carried across.
///
/// `useRootNavigator: true` is what keeps the sheet above the floating
/// navigation bar, but it also mounts the sheet in the root overlay rather than
/// beneath the widget that opened it. If any `ProviderScope` sits below that
/// overlay, a `ConsumerWidget` inside the sheet finds no scope and throws.
/// Re-exposing the container the caller was using makes the sheet immune to
/// wherever the scope happens to live in the tree.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      maxWidth: 640,
    ),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      // The sheet body is built once and handed to the lifter, rather than
      // being re-invoked inside it. Calling `builder(context)` under a widget
      // that watches `viewInsets` rebuilt the entire form — every field, every
      // provider read — on each frame of the keyboard animation.
      child: _KeyboardLift(child: builder(context)),
    ),
  );
}

/// Raises a sheet clear of the keyboard.
///
/// Owns the `viewInsets` subscription so nothing above or below it does. The
/// [child] arrives already built, so this rebuilds alone while the keyboard
/// animates.
class _KeyboardLift extends StatelessWidget {
  const _KeyboardLift({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
}

/// [showDialog] with the caller's provider container carried across, for the
/// same reason [showAppSheet] does it.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final container = ProviderScope.containerOf(context, listen: false);

  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: builder(context),
    ),
  );
}

/// Body layout shared by every sheet: title row, scrolling content, pinned
/// primary action.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSubmit,
    this.submitLabel,
    this.icon,
    this.accent,
    this.isSubmitting = false,
    this.formKey,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSubmit;
  final String? submitLabel;
  final IconData? icon;
  final Color? accent;
  final bool isSubmitting;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? context.colors.primary;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: tint, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(title, style: context.text.titleLarge)),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: context.l10n.cancel,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                disabledBackgroundColor: context.tokens.surfaceHigh,
                disabledForegroundColor: context.tokens.textSecondary,
                elevation: 0,
                textStyle: context.text.labelLarge,
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: context.tokens.textSecondary,
                      ),
                    )
                  : Text(submitLabel ?? context.l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled text field with the app's validation conventions baked in.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.prefixIcon,
    this.keyboardType,
    this.focusNode,
    this.required = false,
    this.numeric = false,
    this.allowDecimal = false,
    this.minLines,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.obscure = false,
    this.textCapitalization,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final bool required;
  final bool numeric;
  final bool allowDecimal;

  /// Height the field starts at, in lines. Null keeps it at one line until
  /// text wraps.
  final int? minLines;

  /// Null lets the field grow without limit, which is what a notes box wants.
  final int? maxLines;

  /// Whether this field holds more than one line of text.
  ///
  /// Drives the keyboard and the Enter key together, because they are one
  /// decision: a field that can hold paragraphs should offer a return key that
  /// inserts a line, not one that submits the form.
  bool get _isMultiline =>
      maxLines == null || maxLines! > 1 || (minLines ?? 1) > 1;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  /// Overrides the resolved default; see [_capitalization].
  final TextCapitalization? textCapitalization;

  /// Sentence case on every free-text field in the app, and on nothing else.
  ///
  /// A field the user types prose into — a note, a workshop name, a nickname —
  /// should start with a capital, and having to reach for shift on every entry
  /// is the kind of friction that stops people writing notes at all. The three
  /// exclusions are not style choices:
  ///
  ///  * **numeric** fields have no letters to capitalise, and the flag changes
  ///    which keyboard some Android IMEs open on.
  ///  * **obscured** fields are passwords, where an unexpected capital is a
  ///    failed sign-in the user cannot see to diagnose.
  ///  * **email** addresses are conventionally lower-case, and a leading
  ///    capital is a rejected login on any case-sensitive local part.
  ///
  /// Resolved here rather than passed in at each of the thirty-odd call sites,
  /// so a new field is correct by default instead of correct if remembered.
  TextCapitalization get _capitalization {
    final explicit = textCapitalization;
    if (explicit != null) return explicit;
    if (numeric || obscure) return TextCapitalization.none;
    if (keyboardType == TextInputType.emailAddress) {
      return TextCapitalization.none;
    }
    return TextCapitalization.sentences;
  }

  /// Hides what is typed, for a password.
  ///
  /// Lives here rather than in the one screen that needs it: a field that looks
  /// and validates like every other field in the app should not be re-made from
  /// `TextFormField` just to add a mask.
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        // A masked field cannot wrap: Flutter asserts on obscureText with more
        // than one line.
        minLines: obscure ? null : minLines,
        maxLines: obscure ? 1 : maxLines,
        onChanged: onChanged,
        // **Enter inserts a line in a multiline field.** The default action
        // closes the keyboard, which on a notes box means the driver cannot
        // write a second line at all — and no other key would.
        textInputAction:
            textInputAction ??
            (_isMultiline && !obscure ? TextInputAction.newline : null),
        textCapitalization: _capitalization,
        keyboardType:
            keyboardType ??
            (numeric
                ? TextInputType.numberWithOptions(decimal: allowDecimal)
                : _isMultiline && !obscure
                ? TextInputType.multiline
                : TextInputType.text),
        inputFormatters: numeric
            ? [
                FilteringTextInputFormatter.allow(
                  allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
              ]
            : null,
        // Numbers stay left-to-right even in an RTL layout, which is how
        // people actually read an odometer or a price.
        textDirection: numeric ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: required ? label : '$label (${l10n.optional})',
          hintText: hint,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          suffixText: suffix,
          // Reserves the helper line so an error appearing under one field
          // cannot push a side-by-side sibling out of alignment.
          helperText: ' ',
          helperMaxLines: 1,
          errorMaxLines: 1,
        ),
        validator:
            validator ??
            (value) {
              final text = value?.trim() ?? '';
              if (required && text.isEmpty) return l10n.required_;
              if (numeric && text.isNotEmpty && num.tryParse(text) == null) {
                return l10n.invalidNumber;
              }
              return null;
            },
      ),
    );
  }
}

/// Date field that opens the platform picker and renders the chosen day.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.calendar_month_rounded,
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final IconData icon;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = value == null
        ? '—'
        : MaterialLocalizations.of(context).formatFullDate(value!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: firstDate ?? DateTime(now.year - 30),
            lastDate: lastDate ?? DateTime(now.year + 30),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: ' ',
            helperMaxLines: 1,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: clearable && value != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: l10n.delete,
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.expand_more_rounded),
          ),
          child: Text(text, style: context.text.bodyLarge),
        ),
      ),
    );
  }
}

/// Label above a row of choice chips — used for fuel grade, expense category,
/// service tier and workshop kind.
class AppChoiceRow<T> extends StatelessWidget {
  const AppChoiceRow({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
    this.iconOf,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color Function(T)? colorOf;
  final IconData Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  selected: value == selected,
                  onSelected: (_) => onChanged(value),
                  avatar: iconOf == null
                      ? null
                      : Icon(
                          iconOf!(value),
                          size: 16,
                          color: value == selected
                              ? (colorOf?.call(value) ?? context.colors.primary)
                              : context.tokens.textSecondary,
                        ),
                  label: Text(labelOf(value)),
                  showCheckmark: false,
                  selectedColor:
                      (colorOf?.call(value) ?? context.colors.primary)
                          .withValues(alpha: 0.18),
                  side: BorderSide(
                    color: value == selected
                        ? (colorOf?.call(value) ?? context.colors.primary)
                              .withValues(alpha: 0.55)
                        : context.tokens.border,
                  ),
                  labelStyle: context.text.labelMedium?.copyWith(
                    color: value == selected
                        ? (colorOf?.call(value) ?? context.colors.primary)
                        : context.tokens.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
