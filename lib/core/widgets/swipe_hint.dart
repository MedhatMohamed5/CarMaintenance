import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Slides a list row aside once, showing the delete backdrop under it, so the
/// driver learns the row can be swiped away.
///
/// Runs a single time per [list], ever: the first row of that list to build
/// takes it and marks it seen before animating, so a row scrolled away or a
/// second list on the same screen never replays it.
class SwipeHint extends ConsumerStatefulWidget {
  const SwipeHint({
    super.key,
    required this.list,
    required this.enabled,
    required this.background,
    required this.child,
  });

  final String list;

  /// True for the list's first row. Read once, when the row first builds.
  final bool enabled;
  final Widget background;
  final Widget child;

  @override
  ConsumerState<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends ConsumerState<SwipeHint>
    with SingleTickerProviderStateMixin {
  static const double _peek = 72;

  /// Only created for the row that plays the hint; every other row builds
  /// its child as is.
  AnimationController? _slide;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    final store = ref.read(preferencesStoreProvider);
    if (store.swipeHintSeen(widget.list)) return;
    store.markSwipeHintSeen(widget.list);
    _play(
      _slide = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      ),
    );
  }

  Future<void> _play(AnimationController slide) async {
    // Let the screen's own entrance finish first.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await slide.forward();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) await slide.reverse();
  }

  @override
  void dispose() {
    _slide?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slide;
    if (slide == null) return widget.child;

    // Rows are dismissed end-to-start, which is leftwards in English and
    // rightwards in Arabic.
    final sign = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: slide,
      child: widget.child,
      // The same tree at rest and in motion, so the row is never rebuilt
      // from scratch when the slide starts or ends.
      builder: (context, child) {
        final dx = sign * _peek * Curves.easeOutCubic.transform(slide.value);
        return Stack(
          children: [
            Positioned.fill(
              child: Visibility(
                visible: slide.value > 0,
                child: widget.background,
              ),
            ),
            Transform.translate(offset: Offset(dx, 0), child: child),
          ],
        );
      },
    );
  }
}
