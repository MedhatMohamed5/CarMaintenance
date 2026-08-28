import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../theme/app_theme.dart';

class GlassCard extends HookWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderRadius,
    this.elevated = false,
    this.blur = true,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool elevated;

  /// Requests a backdrop blur. **Scroll context overrides it** — see
  /// [_blurs].
  ///
  /// Each blurred card costs a `saveLayer`, a framebuffer read and a gaussian
  /// pass. Static chrome pays that once; a card inside a scrollable pays it on
  /// every scroll frame.
  final bool blur;

  /// Whether this card actually blurs, after the scroll context has its say.
  ///
  /// A `BackdropFilter` samples whatever is painted behind it, so inside a
  /// scroll view it has to re-sample and re-blur on **every frame of every
  /// scroll** — the cost is per-frame, not once on entry, and it multiplies by
  /// the number of cards on screen. A dashboard of nine blurred cards is nine
  /// framebuffer reads per frame, which is what made scrolling stutter.
  ///
  /// Deciding it here rather than at each call site is deliberate: the rule is
  /// a property of *where the card is*, not of what it contains, and the four
  /// call sites that had remembered to pass `blur: false` were the four that
  /// had already been profiled. The rest had simply not been noticed yet.
  ///
  /// `Scrollable.maybeOf` depends on `_ScrollableScope`, whose
  /// `updateShouldNotify` compares the `ScrollPosition` by identity — that
  /// object does not change as the offset changes, so this subscription costs
  /// nothing per frame.
  static bool _blurs(BuildContext context, {required bool requested}) =>
      requested && Scrollable.maybeOf(context) == null;

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    void setPressed(bool value) {
      if (onTap == null || pressed.value == value) return;
      pressed.value = value;
    }

    final tokens = context.tokens;
    final blurs = _blurs(context, requested: blur);
    final radius = borderRadius ?? BorderRadius.circular(tokens.cardRadius);
    final surface = context.colors.surface;
    final isDark = context.isDark;
    final accentColor = accent;

    final body = AnimatedContainer(
      duration: AppDurations.expand,
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: surface.withValues(alpha: blurs ? 0.86 : 1),
        border: Border.all(
          color: accentColor == null
              ? tokens.border
              : Color.alphaBlend(
                  accentColor.withValues(alpha: pressed.value ? 0.55 : 0.34),
                  tokens.border,
                ),
        ),
        gradient: accentColor == null
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: isDark ? 0.05 : 0.0),
                    surface,
                  ),
                  surface,
                ],
              )
            : LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color.alphaBlend(
                    accentColor.withValues(alpha: tokens.glowOpacity * 0.7),
                    surface,
                  ),
                  Color.alphaBlend(
                    accentColor.withValues(alpha: tokens.glowOpacity * 0.12),
                    surface,
                  ),
                  surface,
                ],
                stops: const [0, 0.55, 1],
              ),
        boxShadow: [
          if (elevated)
            BoxShadow(
              color: (accentColor ?? Colors.black).withValues(
                alpha: isDark ? 0.38 : 0.14,
              ),
              blurRadius: 30,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: pressed.value ? 8 : 16,
            offset: Offset(0, pressed.value ? 2 : 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (accentColor != null)
            PositionedDirectional(
              top: -1,
              start: 24,
              end: 24,
              child: Container(
                height: 1.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0),
                      accentColor.withValues(alpha: isDark ? 0.75 : 0.4),
                      accentColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              onTapDown: (_) => setPressed(true),
              onTapUp: (_) => setPressed(false),
              onTapCancel: () => setPressed(false),
              borderRadius: radius,
              splashColor: accentColor?.withValues(alpha: 0.10),
              highlightColor: Colors.transparent,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ],
      ),
    );

    final card = blurs
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: body,
            ),
          )
        : body;

    // Own layer per card. Without it a press on one row, or any implicit
    // animation inside it, dirties the whole scrollable and repaints every
    // sibling; with it the damage stops at this card's bounds.
    return RepaintBoundary(
      child: AnimatedScale(
        scale: pressed.value ? 0.985 : 1,
        duration: AppDurations.press,
        curve: Curves.decelerate,
        child: card,
      ),
    );
  }
}

class AccentIconBadge extends StatelessWidget {
  const AccentIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.72)],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.08),
                ],
              ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.30)),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.42),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: (size * 0.5).roundToDouble(),
        color: filled ? context.colors.surface : color,
      ),
    );
  }
}
