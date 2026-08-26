import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'animation_keep_alive.dart';
import 'common_widgets.dart';

/// Counts a number up on first mount, then tracks later changes.
///
/// Two distinct jobs, deliberately kept apart:
///
/// * **Mount** — counts from zero to the value, which is the flourish a stats
///   card wants. Runs once per element, from a `useEffect` with an empty key
///   list, and the element is held by an [AnimationKeepAlive] so a lazy list
///   cannot dispose it on the way out and replay the count on the way back.
/// * **Change** — when the underlying figure genuinely changes (a fill is
///   logged, the odometer moves) it tweens from the old value to the new one,
///   so the number reads as a change rather than a redraw.
///
/// [format] receives the interpolated value and returns the display string, so
/// currency, decimals and Latin-digit pinning all stay with the caller and this
/// widget never has to know about locale.
class AnimatedCounter extends HookWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.format,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.fastOutSlowIn,
  });

  final double value;

  /// Formats an interpolated value for display.
  final String Function(double value) format;

  /// Renders the formatted string. Kept as a builder so the caller controls
  /// typography, units and layout.
  final Widget Function(BuildContext context, String text) builder;

  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);

    final controller = useAnimationController(
      duration: duration,
      initialValue: animate ? 0 : 1,
    );

    // Where this run started. Zero on mount; the previous figure afterwards, so
    // a change tweens between the two instead of restarting from nothing.
    final from = useRef(0.0);
    final target = useRef(value);

    /// The figure currently on screen, so a retarget starts from what the user
    /// can actually see.
    final shownRef = useRef(0.0);

    useEffect(() {
      if (animate) controller.forward();
      return null;
    }, const []);

    // Fires only when `value` actually differs, not on every rebuild.
    //
    // A figure that changes while the first count is still running retargets
    // it instead of starting over: on the dashboard these mount before their
    // data has settled, and restarting read as the number counting up twice.
    useEffect(() {
      if (target.value == value) return null;
      final settledOnce = controller.isCompleted;
      if (settledOnce) from.value = shownRef.value;
      target.value = value;
      if (!animate) {
        controller.value = 1;
        return null;
      }
      if (settledOnce) {
        controller.forward(from: 0);
      }
      return null;
    }, [value]);

    final t = curve.transform(useAnimation(controller).clamp(0.0, 1.0));
    final shown = from.value + (target.value - from.value) * t;
    shownRef.value = shown;

    return AnimationKeepAlive(
      child: RepaintBoundary(child: builder(context, format(shown))),
    );
  }
}

/// A [StatValue] whose number counts up on mount.
///
/// The formatter, not this widget, decides how the figure reads — `Fmt.money`,
/// `Fmt.dec2`, a metric conversion — so currency, decimals and Latin-digit
/// pinning stay with the caller and Arabic renders the same as English.
///
/// [emptyLabel] short-circuits the count when there is nothing to show, so a
/// tile with no data prints a dash instead of ticking up to zero.
class CountingStatValue extends StatelessWidget {
  const CountingStatValue({
    super.key,
    required this.value,
    required this.format,
    this.unit,
    this.color,
    this.style,
    this.emptyLabel,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double value) format;
  final String? unit;
  final Color? color;
  final TextStyle? style;

  /// Shown instead of a count when [value] is not positive.
  final String? emptyLabel;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final empty = emptyLabel;
    if (empty != null && value <= 0) {
      return StatValue(
        value: empty,
        unit: unit,
        color: color,
        style: style,
        animate: false,
      );
    }

    return AnimatedCounter(
      value: value,
      duration: duration,
      format: format,
      builder: (context, text) => StatValue(
        value: text,
        unit: unit,
        color: color,
        style: style,
        animate: false,
      ),
    );
  }
}
