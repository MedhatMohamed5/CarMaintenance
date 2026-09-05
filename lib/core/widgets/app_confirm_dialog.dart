import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The one shape every yes/no in the app is asked in.
///
/// **Built on [Dialog] rather than [AlertDialog] because of the button row.**
/// `AlertDialog` hands its actions to an `OverflowBar`, which asks each child
/// for its preferred width — and the app's `filledButtonTheme` sets
/// `minimumSize: Size.fromHeight(52)`, whose width is `double.infinity`. Every
/// action therefore claimed the full dialog, overflowed the row, and got
/// stacked into two 52-pixel slabs with the question squeezed above them.
/// Laying the actions out here, in a [Row] of equal halves with their own
/// bounded [ButtonStyle.minimumSize], is what keeps them a pair of buttons
/// instead of the dialog's main event.
///
/// The header icon carries the intent: red and a warning glyph when the answer
/// destroys something, the accent and a question mark when it does not. Colour
/// and wording are chosen together by the caller — see `confirmAction`.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.icon,
    this.destructive = true,
  });

  /// The question itself, in one line if possible.
  final String title;

  /// Consequences worth spelling out. Omitted for a question that speaks for
  /// itself — a delete prompt does not need a paragraph.
  final String? message;

  final String? confirmLabel;
  final String? cancelLabel;

  /// Overrides the glyph resolved from [destructive].
  final IconData? icon;

  final bool destructive;

  /// Narrow enough that the two actions stay legible as buttons and the text
  /// keeps a comfortable measure on a tablet.
  static const double _maxWidth = 360;

  /// Bounded on both axes, against a theme whose default button width is
  /// infinite.
  static const Size _actionSize = Size(0, 46);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tint = destructive ? AppColors.red : context.colors.primary;

    return Dialog(
      backgroundColor: context.colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: context.tokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntentIcon(
                icon:
                    icon ??
                    (destructive
                        ? Icons.delete_outline_rounded
                        : Icons.help_outline_rounded),
                color: tint,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: _actionSize,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: context.tokens.textSecondary,
                      ),
                      child: _ActionLabel(cancelLabel ?? l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        minimumSize: _actionSize,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: tint,
                        foregroundColor: destructive
                            ? Colors.white
                            : context.colors.onPrimary,
                      ),
                      child: _ActionLabel(confirmLabel ?? l10n.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The intent, said in colour before it is said in words.
class _IntentIcon extends StatelessWidget {
  const _IntentIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }
}

/// A button label that shrinks rather than wraps.
///
/// Two buttons share the width, and the app allows text scaling up to 1.3 —
/// "Confirm service done" at that size would otherwise wrap to three lines and
/// take the row's height with it.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1, softWrap: false),
  );
}
