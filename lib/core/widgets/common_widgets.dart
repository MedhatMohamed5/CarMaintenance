import 'package:flutter/material.dart';

import '../constants/app_durations.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'app_confirm_dialog.dart';
import 'app_sheet.dart';

/// Title + optional trailing action above a group of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 10),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: context.tokens.textSecondary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: context.text.titleSmall?.copyWith(
                color: context.tokens.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A number with its unit, animated so a value change reads as a change rather
/// than a redraw.
class StatValue extends StatelessWidget {
  const StatValue({
    super.key,
    required this.value,
    this.unit,
    this.color,
    this.style,
    this.animate = true,
  });

  final String value;
  final String? unit;
  final Color? color;
  final TextStyle? style;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.numeric(
      (style ?? context.text.headlineSmall)?.copyWith(
        color: color ?? context.colors.onSurface,
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            value,
            style: base,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(
            unit!,
            maxLines: 1,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (!animate) return content;
    return AnimatedSwitcher(
      duration: AppDurations.entrance,
      switchInCurve: Curves.fastOutSlowIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          axis: Axis.horizontal,
          sizeFactor: animation,
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey('$value$unit'), child: content),
    );
  }
}

/// Rounded label chip used for tags (fuel grade, service tier, category).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    final bg = selected
        ? tint.withValues(alpha: 0.18)
        : context.tokens.surfaceHigh;
    final fg = selected ? tint : context.tokens.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: AppDurations.stateChange,
          curve: Curves.decelerate,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 13,
            vertical: dense ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? tint.withValues(alpha: 0.5)
                  : context.tokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 13 : 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style:
                    (dense ? context.text.labelSmall : context.text.labelMedium)
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with an optional call to action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final glyph = dense ? 56.0 : 64.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: dense ? 16 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: glyph,
                height: glyph,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.tokens.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.tokens.border),
                  ),
                  child: Icon(
                    icon,
                    size: glyph * 0.44,
                    color: context.tokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleSmall,
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One-line snackbar helper so feedback looks the same everywhere.
///
/// Pass [actionLabel] and [onAction] together to attach a button — see
/// [showUndoSnack], which is the only shape the app actually uses.
void showAppSnack(
  BuildContext context,
  String message, {
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  final hasAction = actionLabel != null && onAction != null;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.colors.primary),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 12),
        // Two seconds is enough to register "saved". It is not enough to read
        // a message, realise the deletion was a mistake, and reach the button
        // — so an actionable snackbar gets long enough to actually act on.
        duration: Duration(seconds: hasAction ? 6 : 2),
        // **`persist` defaults to `action != null`.** Left alone, every
        // snackbar carrying a button sits on screen until it is tapped or
        // swiped: `ScaffoldMessenger` reads this flag inside the timeout it
        // already scheduled and returns without hiding anything, so `duration`
        // silently stops meaning anything. Undo is an offer, not a prompt —
        // ignoring it is an answer, and the bar should leave on its own.
        persist: false,
        action: hasAction
            ? SnackBarAction(
                label: actionLabel,
                textColor: context.colors.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
}

/// Reports a deletion and leaves the way back on screen.
///
/// **Confirmation and undo answer different questions, and the app needs
/// both.** A dialog asks before the fact, when the user is certain and has not
/// yet seen the consequence; undo answers after it, when they have. The dialog
/// stays because these deletions cascade, but it is the swipe that gets
/// mis-fired — a thumb on a scrolling list — and a confirmation tapped through
/// on reflex is no protection at all.
///
/// [onUndo] must not close over a `WidgetRef` or a `BuildContext` belonging to
/// the row being deleted: by the time it runs, that element is gone. Read a
/// `ProviderContainer` before deleting and close over that instead.
void showUndoSnack(
  BuildContext context, {
  required VoidCallback onUndo,
  String? message,
}) {
  final l10n = AppLocalizations.of(context);
  showAppSnack(
    context,
    message ?? l10n.raw('deleted'),
    icon: Icons.delete_outline_rounded,
    actionLabel: l10n.raw('undo'),
    onAction: onUndo,
  );
}

/// Red "swipe to delete" backdrop shared by every dismissible list row.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171)),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: const Color(0xFFF87171),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard "are you sure?" for destructive row actions.
/// A yes/no the caller can trust before doing something hard to undo.
///
/// **The wording and the colour move together.** [message] alone was not
/// enough: overriding only the text left sign-out asking "sign out?" over a red
/// button reading *Delete*, which describes an action that does not happen and
/// warns about a danger that does not exist. A confirmation that misnames its
/// own outcome is worse than none — the user either hesitates over something
/// harmless or, worse, learns to ignore the red.
///
/// [title] and [message] split the question from its consequences. Passing
/// only [message] keeps it as the question, which is what every delete call
/// site does and why they are unchanged.
Future<bool> confirmAction(
  BuildContext context, {
  String? title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  IconData? icon,
  bool destructive = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final question = title ?? message ?? l10n.confirmDelete;

  final result = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppConfirmDialog(
      title: question,
      // Never repeated underneath itself when the caller gave only one string.
      message: message == question ? null : message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

/// The destructive case, kept for the call sites that mean exactly that.
Future<bool> confirmDelete(BuildContext context, {String? message}) =>
    confirmAction(context, message: message);
