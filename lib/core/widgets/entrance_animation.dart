import 'package:flutter/material.dart';

/// Plays a fade-and-rise exactly once, the first time this element is built.
///
/// `flutter_animate`'s `.animate()` rebuilds its whole effect chain whenever
/// the widget rebuilds, and inside a scrollable that happens constantly — a
/// parent `setState`, a provider emission, or an item being recycled all
/// restart the fade. Rows blinked every time the list moved.
///
/// The controller here lives in `initState`, `forward()` is called once behind
/// a `_played` latch, and `didUpdateWidget` deliberately does nothing. Once the
/// animation has completed the controller is left parked at 1.0 and the
/// subtree is returned untouched, so a settled list costs nothing per frame:
/// no ticker, no `AnimatedBuilder`, no opacity or transform layer.
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

class EntranceAnimation extends StatefulWidget {
  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.slide = 0.04,
    this.enabled = true,
  });

  /// Convenience for list items: staggers by [step] per index and caps the
  /// stagger at [maxSteps] so the tail of a long list is not left waiting.
  ///
  /// A [ValueKey] on the item's own identity keeps the element — and therefore
  /// the "already played" state — attached to the row rather than to the slot,
  /// so reordering or inserting does not replay a neighbour's animation.
  factory EntranceAnimation.item({
    required Key key,
    required Widget child,
    required int index,
    Duration step = const Duration(milliseconds: 40),
    int maxSteps = 8,
    Duration duration = const Duration(milliseconds: 300),
    double slide = 0.04,
  }) => EntranceAnimation(
    key: key,
    delay: step * index.clamp(0, maxSteps),
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
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _offset = Tween<Offset>(
    begin: Offset(0, widget.slide),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  /// Execution guard. Guarantees `forward()` is reachable exactly once for the
  /// lifetime of this element, no matter how many times `build` runs.
  bool _hasAnimated = false;

  /// Keeps this element alive when it scrolls out of a lazy viewport.
  ///
  /// Without it a `SliverList` disposes the row on exit and rebuilds it on
  /// re-entry, which resets [_hasAnimated] with the fresh `State` and replays
  /// the fade. Scrolling up and down made every row blink. Keeping the element
  /// alive is what makes "once" actually mean once.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _runOnce();
  }

  /// Called only from [initState]. Nothing in the build path, and nothing in
  /// `didUpdateWidget`, can reach it — a scroll notification or a parent
  /// rebuild therefore cannot restart the timeline.
  void _runOnce() {
    if (_hasAnimated) return;
    _hasAnimated = true;

    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }

    // A delayed start must survive the element being disposed mid-wait, which
    // is exactly what happens when a row scrolls out before its turn.
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  // Intentionally not overriding didUpdateWidget: a changed delay, duration or
  // child is never a reason to replay an entrance that has already happened.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin: registers the keep-alive with
    // the enclosing sliver.
    super.build(context);

    // Settled: hand back the child with no wrapper at all, so a resting list
    // has zero animation overhead per frame.
    if (_controller.isCompleted || !widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      // Built once, re-used every tick — the subtree is composited, not rebuilt.
      child: widget.child,
      builder: (context, child) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _offset, child: child),
      ),
    );
  }
}
