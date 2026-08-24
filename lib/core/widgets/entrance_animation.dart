import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Plays a fade-and-rise exactly once, the first time this element is built.
///
/// `flutter_animate`'s `.animate()` rebuilds its whole effect chain whenever
/// the widget rebuilds, and inside a scrollable that happens constantly — a
/// parent `setState`, a provider emission, or an item being recycled all
/// restart the fade. Rows blinked every time the list moved.
///
/// The controller is created by [useAnimationController] and [useEffect] calls
/// `forward()` once behind a [useRef] latch. Rebuilds never replay the
/// timeline. Once the animation has completed the controller is left parked at
/// 1.0 and the subtree is returned untouched, so a settled list costs nothing
/// per frame: no ticker, no `AnimatedBuilder`, no opacity or transform layer.
///
/// The child is captured once and reused across every tick, so the subtree is
/// never rebuilt by the animation itself — only re-composited.
/// Resolves a recycled child's key back to its index for a `SliverList`.
///
/// Without it, a sliver that has scrolled away rebuilds its children from
/// scratch after an insert or delete, which loses the "already played" state
/// inside [EntranceAnimation] and makes settled rows fade in again. Pass the
/// same key format the item builder uses.
int? indexOfChildKey(Key key, int itemCount, String Function(int index) keyOf) {
  if (key is! ValueKey<String>) return null;
  for (var i = 0; i < itemCount; i++) {
    if (keyOf(i) == key.value) return i;
  }
  return null;
}

class EntranceAnimation extends HookWidget {
  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.slide = 0.04,
    this.enabled = true,
  });

  /// Convenience for list items: staggers by [step] per index and caps the
  /// stagger at [cap] so the tail of a long list is not left waiting.
  ///
  /// A [ValueKey] on the item's own identity keeps the element — and therefore
  /// the "already played" state — attached to the row rather than to the slot,
  /// so reordering or inserting does not replay a neighbour's animation.
  factory EntranceAnimation.item({
    required Key key,
    required Widget child,
    required int index,
    Duration step = const Duration(milliseconds: 40),
    int cap = 8,
    Duration duration = const Duration(milliseconds: 300),
    double slide = 0.04,
  }) => EntranceAnimation(
    key: key,
    delay: step * index.clamp(0, cap),
    duration: duration,
    slide: slide,
    child: child,
  );

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical offset to rise from, as a fraction of the child's height.
  final double slide;

  /// When false the child is returned as-is — used to switch the effect off
  /// wholesale (reduced-motion, tests, very long lists).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Keeps this element alive when it scrolls out of a lazy viewport.
    //
    // Without it a `SliverList` disposes the row on exit and rebuilds it on
    // re-entry, which resets the latch with a fresh hook state and replays
    // the fade. Scrolling up and down made every row blink. Keeping the
    // element alive is what makes "once" actually mean once.
    useAutomaticKeepAlive();

    final controller = useAnimationController(duration: duration);
    final fade = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeOut),
      [controller],
    );
    final offset = useMemoized(
      () => Tween<Offset>(begin: Offset(0, slide), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      ),
      [controller],
    );

    /// Execution guard. Guarantees `forward()` is reachable exactly once for
    /// the lifetime of this element, no matter how many times `build` runs.
    final hasAnimated = useRef(false);

    useEffect(() {
      if (hasAnimated.value) return null;
      hasAnimated.value = true;

      if (!enabled) {
        controller.value = 1;
        return null;
      }

      if (delay == Duration.zero) {
        controller.forward();
        return null;
      }

      // A delayed start must survive the element being disposed mid-wait, which
      // is exactly what happens when a row scrolls out before its turn.
      var disposed = false;
      Future<void>.delayed(delay, () {
        if (!disposed) controller.forward();
      });
      return () => disposed = true;
    }, const []);

    if (controller.isCompleted || !enabled) return child;

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: offset, child: child),
      ),
    );
  }
}
