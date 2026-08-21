import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.duration = const Duration(milliseconds: 1100),
    this.delay = Duration.zero,
    this.trackColor,
    this.showGlow = true,
  });

  final double value;
  final Color color;
  final double height;
  final Duration duration;
  final Duration delay;
  final Color? trackColor;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final total = duration + delay;
    final startFraction = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: total,
      curve: Interval(startFraction, 1, curve: Curves.easeOutCubic),
      builder: (context, t, _) => LayoutBuilder(
        builder: (context, constraints) {
          final filled = constraints.maxWidth * t;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: trackColor ?? context.tokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(height),
                    border: Border.all(
                      color: context.tokens.border.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Container(
                  width: filled,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        color.withValues(alpha: 0.55),
                        color,
                        Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.35),
                          color,
                        ),
                      ],
                      stops: const [0, 0.75, 1],
                    ),
                    boxShadow: showGlow && context.isDark
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 12,
                              spreadRadius: -1,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
                if (filled > height * 1.6)
                  PositionedDirectional(
                    start: 0,
                    top: 1.5,
                    width: filled,
                    height: height * 0.34,
                    child: Container(
                      margin: EdgeInsetsDirectional.only(
                        start: height * 0.4,
                        end: height * 0.4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AnimatedRingGauge extends StatelessWidget {
  const AnimatedRingGauge({
    super.key,
    required this.value,
    required this.color,
    required this.child,
    this.size = 118,
    this.strokeWidth = 10,
  });

  final double value;
  final Color color;
  final Widget child;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (context.isDark)
              Container(
                width: size * 0.86,
                height: size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22 * t),
                      blurRadius: 26,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(context.tokens.surfaceHigh),
              ),
            ),
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: t,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
