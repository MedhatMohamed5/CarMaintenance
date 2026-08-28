import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../theme/app_theme.dart';
import 'animation_keep_alive.dart';

/// A progress bar that fills once on mount, then follows the value.
///
/// The controller is built once per element and driven from a `useEffect` with
/// an empty key list, so a rebuild cannot restart the fill. Building once is
/// only half of it: the element also has to survive, or a lazy list disposes
/// the bar on the way out and the fill replays on the way back — hence the
/// [AnimationKeepAlive] around it. A later change to [value] re-runs the tween
/// from where the bar currently sits rather than from zero.
class AnimatedProgressBar extends HookWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.trackColor,
    this.showGlow = true,
    this.duration = AppDurations.valueFill,
    this.delay = Duration.zero,
  });

  final double value;
  final Color color;
  final double height;
  final Color? trackColor;
  final bool showGlow;
  final Duration duration;

  /// Staggers the fill when several bars sit in one card.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final animate = !MediaQuery.disableAnimationsOf(context);

    final controller = useAnimationController(
      duration: duration,
      initialValue: animate ? 0 : 1,
    );

    final from = useRef(0.0);
    final target = useRef(clamped);

    /// What the bar is showing right now. Kept so a retarget can start from the
    /// visible position instead of recomputing it from the tween.
    final shownRef = useRef(0.0);

    useEffect(() {
      if (!animate) return null;
      if (delay == Duration.zero) {
        controller.forward();
        return null;
      }
      var cancelled = false;
      Future<void>.delayed(delay).then((_) {
        if (!cancelled && controller.isDismissed) controller.forward();
      });
      return () => cancelled = true;
    }, const []);

    useEffect(() {
      if (target.value == clamped) return null;

      // **A value that arrives while the first fill is still running is part of
      // that fill, not a second one.** The dashboard mounts these bars before
      // the data behind them has settled, so the figure often changes a frame
      // or two after the card appears; the sheet is opened by hand, long after
      // everything has settled, which is the whole reason one replayed and the
      // other did not. Retargeting the running tween lets it simply land
      // somewhere else — the user sees one fill, to the right number.
      final settledOnce = controller.isCompleted;
      target.value = clamped;

      if (!animate) {
        controller.value = 1;
        return null;
      }
      if (settledOnce) {
        // A genuine later change: tween from where the bar actually sits.
        // This used to be `target * controller.value`, which is only the shown
        // value while `from` is still zero — after the first retarget it was
        // wrong, and the bar jumped before moving.
        from.value = shownRef.value;
        controller.forward(from: 0);
      }
      return null;
    }, [clamped]);

    final t = Curves.fastOutSlowIn.transform(
      useAnimation(controller).clamp(0.0, 1.0),
    );
    final shown = (from.value + (target.value - from.value) * t).clamp(
      0.0,
      1.0,
    );
    shownRef.value = shown;

    return AnimationKeepAlive(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 0.0;
            final filled = (maxWidth * shown).clamp(0.0, maxWidth);

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
                  // Specular highlight along the filled portion, skipped when the
                  // bar is too short to carry it.
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
      ),
    );
  }
}

/// Ring gauge that sweeps to its value once on mount, then follows changes.
///
/// Same discipline as [AnimatedProgressBar]: the controller is built once per
/// element and the element is kept alive, so a card scrolled out of view and
/// back does not re-sweep. The
/// centre [child] is memoised and lifted out of the per-tick rebuild, which
/// matters because it is usually a formatted number with its own layout.
class AnimatedRingGauge extends HookWidget {
  const AnimatedRingGauge({
    super.key,
    required this.value,
    required this.color,
    required this.child,
    this.size = 118,
    this.strokeWidth = 10,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final Color color;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final animate = !MediaQuery.disableAnimationsOf(context);

    final controller = useAnimationController(
      duration: duration,
      initialValue: animate ? 0 : 1,
    );

    final from = useRef(0.0);
    final target = useRef(clamped);
    final shownRef = useRef(0.0);

    useEffect(() {
      if (animate) controller.forward();
      return null;
    }, const []);

    // Same rule as [AnimatedProgressBar]: a value arriving mid-sweep retargets
    // the sweep rather than starting a second one.
    useEffect(() {
      if (target.value == clamped) return null;
      final settledOnce = controller.isCompleted;
      target.value = clamped;

      if (!animate) {
        controller.value = 1;
        return null;
      }
      if (settledOnce) {
        from.value = shownRef.value;
        controller.forward(from: 0);
      }
      return null;
    }, [clamped]);

    final progress = Curves.fastOutSlowIn.transform(
      useAnimation(controller).clamp(0.0, 1.0),
    );
    final t = (from.value + (target.value - from.value) * progress).clamp(
      0.0,
      1.0,
    );
    shownRef.value = t;

    final isDark = context.isDark;
    final trackColor = context.tokens.surfaceHigh;

    return AnimationKeepAlive(
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isDark)
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
                  valueColor: AlwaysStoppedAnimation(trackColor),
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
      ),
    );
  }
}
