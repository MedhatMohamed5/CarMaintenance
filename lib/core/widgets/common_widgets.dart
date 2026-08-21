import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

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
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: context.tokens.textSecondary),
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
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: base),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(
            unit!,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (!animate) return content;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
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
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 13 : 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: (dense ? context.text.labelSmall : context.text.labelMedium)
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
void showAppSnack(BuildContext context, String message, {IconData? icon}) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
        duration: const Duration(seconds: 2),
      ),
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
          const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFF87171),
          ),
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
Future<bool> confirmDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      content: Text(l10n.confirmDelete),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF87171),
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
