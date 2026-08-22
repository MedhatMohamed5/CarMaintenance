import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
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

  /// Backdrop blur. Each blurred card costs a `saveLayer` and a framebuffer
  /// read, so list rows — which sit on an opaque surface and gain nothing
  /// visually — pass `false` and the scrollable stays at frame budget.
  final bool blur;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(tokens.cardRadius);
    final accent = widget.accent;
    final surface = context.colors.surface;
    final isDark = context.isDark;

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: surface.withValues(alpha: widget.blur ? 0.86 : 1),
        border: Border.all(
          color: accent == null
              ? tokens.border
              : Color.alphaBlend(
                  accent.withValues(alpha: _pressed ? 0.55 : 0.34),
                  tokens.border,
                ),
        ),
        gradient: accent == null
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
                    accent.withValues(alpha: tokens.glowOpacity * 0.7),
                    surface,
                  ),
                  Color.alphaBlend(
                    accent.withValues(alpha: tokens.glowOpacity * 0.12),
                    surface,
                  ),
                  surface,
                ],
                stops: const [0, 0.55, 1],
              ),
        boxShadow: [
          if (widget.elevated)
            BoxShadow(
              color: (accent ?? Colors.black).withValues(
                alpha: isDark ? 0.38 : 0.14,
              ),
              blurRadius: 30,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: _pressed ? 8 : 16,
            offset: Offset(0, _pressed ? 2 : 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (accent != null)
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
                      accent.withValues(alpha: 0),
                      accent.withValues(alpha: isDark ? 0.75 : 0.4),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              borderRadius: radius,
              splashColor: accent?.withValues(alpha: 0.10),
              highlightColor: Colors.transparent,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ],
      ),
    );

    final card = widget.blur
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
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
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
