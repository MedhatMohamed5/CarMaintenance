import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../theme/app_theme.dart';
import '../theme/contrast.dart';

/// Visual weight of an [AppActionButton].
enum AppActionStyle {
  /// Solid accent fill. For the one action a card exists to offer.
  filled,

  /// Transparent fill behind a crisp accent outline. For a secondary action,
  /// or when a solid fill would fight a photographic backdrop.
  outlined,
}

/// A compact action that always reads as clickable.
///
/// The previous pill used a 14% tint of the accent as its fill, which over the
/// vehicle photo backdrop landed somewhere between "muted chip" and "disabled
/// control" — the button looked switched off. Two rules fix that:
///
/// * **Ink is chosen by contrast ratio, not picked by hand.** [Contrast.inkOn]
///   compares both candidates against the actual fill, so the label stays
///   legible whether the accent is cyan, amber or navy.
/// * **Disabled looks disabled, and nothing else does.** An enabled button is
///   saturated, elevated and outlined; a disabled one is flat, muted and
///   shadowless. The two states are never a matter of degree.
class AppActionButton extends HookWidget {
  const AppActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.style = AppActionStyle.filled,
    this.dense = false,
  });

  final IconData icon;
  final String label;

  /// Accent the action belongs to. Drives the fill, the outline and — through
  /// [Contrast.inkOn] — the label and icon colour.
  final Color color;

  /// `null` disables the button, which is the *only* way to get the muted
  /// treatment.
  final VoidCallback? onPressed;

  final AppActionStyle style;
  final bool dense;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    void setPressed(bool value) {
      if (!_enabled || pressed.value == value) return;
      pressed.value = value;
    }

    final tokens = context.tokens;
    final radius = BorderRadius.circular(dense ? 12 : 14);

    final enabled = _enabled;
    final filled = style == AppActionStyle.filled;

    // Disabled is a flat, muted surface with no accent anywhere: there is
    // nothing to mistake for an active control.
    final Color background;
    final Color ink;
    final Color outline;

    if (!enabled) {
      background = tokens.surfaceHigh;
      ink = tokens.textSecondary;
      outline = tokens.border;
    } else if (filled) {
      background = color;
      ink = Contrast.inkOn(color);
      // A hairline of the ink separates the fill from a same-toned backdrop,
      // which a flat pill on a photo otherwise melts into.
      outline = ink.withValues(alpha: 0.22);
    } else {
      background = context.colors.surface.withValues(alpha: 0.72);
      ink = color;
      outline = color.withValues(alpha: 0.65);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedScale(
        scale: pressed.value ? 0.96 : 1,
        duration: AppDurations.press,
        curve: Curves.decelerate,
        child: AnimatedContainer(
          duration: AppDurations.stateChange,
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(
              color: outline,
              width: filled && enabled ? 1 : 1.4,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (filled ? color : Colors.black).withValues(
                        alpha: filled ? 0.34 : 0.16,
                      ),
                      blurRadius: pressed.value ? 6 : 14,
                      spreadRadius: -2,
                      offset: Offset(0, pressed.value ? 1 : 4),
                    ),
                  ]
                // Shadowless when disabled: elevation is the strongest
                // "you can press this" signal on the card.
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              onTapDown: (_) => setPressed(true),
              onTapUp: (_) => setPressed(false),
              onTapCancel: () => setPressed(false),
              borderRadius: radius,
              splashColor: ink.withValues(alpha: 0.12),
              highlightColor: ink.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 11 : 14,
                  vertical: dense ? 8 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: dense ? 15 : 17, color: ink),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
