import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'animation_keep_alive.dart';

/// Resolves a recycled child's key back to its index for a `SliverList`.
///
/// Without it, a sliver that has scrolled away rebuilds its children from
/// scratch after an insert or delete. The element — and with it the "already
/// played" flag inside [EntranceAnimation] — is lost, and settled rows fade in
/// again. Pass the same key format the item builder uses.
int? indexOfChildKey(Key key, int itemCount, String Function(int index) keyOf) {
  if (key is! ValueKey<String>) return null;
  for (var i = 0; i < itemCount; i++) {
    if (keyOf(i) == key.value) return i;
  }
  return null;
}

/// Fades and lifts its child into place exactly once, the first time this
/// element is mounted.
///
/// Scroll repetition is prevented three ways, and all three are needed:
///
/// * **The controller is created once per element.** `useAnimationController`
///   with no `keys` builds on first frame and is reused for every rebuild
///   after, so a parent `setState` or a provider emission cannot restart it.
/// * **`forward()` runs from a `useEffect` with an empty key list**, which
///   fires once per mount and never again.
/// * **`AutomaticKeepAlive` holds the element alive off-screen.** A lazy
///   `SliverList` otherwise disposes a row on exit and rebuilds it on re-entry,
///   which resets everything above and replays the fade. Keeping the element is
///   what makes "once" actually mean once.
///
/// Once settled the child is returned bare — no ticker, no `AnimatedBuilder`,
/// no opacity or transform layer — so a resting list costs nothing per frame.
class EntranceAnimation extends HookWidget {
  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.slide = 0.05,
    this.enabled = true,
  });

  /// Convenience for list rows: staggers by [step] per index and caps the
  /// stagger at [cap] so the tail of a long list is not left waiting.
  ///
  /// Key the item on its own identity (`ValueKey('fuel-${log.id}')`), never on
  /// the slot index, so the played state travels with the row and inserting or
  /// deleting never replays a neighbour.
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

  /// `false` returns the child untouched — for reduced-motion, or a list long
  /// enough that staggering stops being an asset.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Respect the platform accessibility setting: motion is decoration here,
    // never information.
    final animate = enabled && !MediaQuery.disableAnimationsOf(context);

    final controller = useAnimationController(
      duration: duration,
      initialValue: animate ? 0 : 1,
    );

    useEffect(() {
      if (!animate) return null;
      if (delay == Duration.zero) {
        controller.forward();
        return null;
      }
      // A delayed start has to survive the element being disposed mid-wait,
      // which is exactly what happens when a row scrolls out before its turn.
      final timer = Future<void>.delayed(delay);
      var cancelled = false;
      timer.then((_) {
        if (!cancelled && controller.isDismissed) controller.forward();
      });
      return () => cancelled = true;
    }, const []);

    // `useAnimation` rebuilds this widget per tick, which is cheap: the child
    // below is memoised, so only the two transition layers are rebuilt.
    final t = useAnimation(controller);
    final settled = t >= 1;

    final memoChild = useMemoized(() => RepaintBoundary(child: child), [child]);

    return AnimationKeepAlive(
      // Settled: hand the child back with no wrapper at all.
      child: settled
          ? memoChild
          : Opacity(
              opacity: Curves.easeOut.transform(t),
              child: Transform.translate(
                offset: Offset(
                  0,
                  slide * 40 * (1 - Curves.easeOut.transform(t)),
                ),
                child: memoChild,
              ),
            ),
    );
  }
}
