import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../theme/app_theme.dart';

/// One coloured stream of a [SpendCompositionBar].
class SpendSegment {
  const SpendSegment({required this.amount, required this.color});

  final double amount;
  final Color color;
}

/// Proportional stacked bar showing how a total splits across its streams.
///
/// **One clip, taken on the outer radius.** The segments inside are square, so
/// only the far-left and far-right tips come out curved and every inner divider
/// stays a clean vertical edge. Rounding each segment separately produced a
/// chain-of-pills look that did not match any other bar in the app.
///
/// Fill gradient, sheen and dark-theme glow are lifted from
/// `AnimatedProgressBar`, so this and the maintenance progress bar read as the
/// same material. It sweeps out from the leading edge once on mount and then
/// holds still; scrolling it away and back does not replay the sweep.
class SpendCompositionBar extends HookWidget {
  const SpendCompositionBar({
    super.key,
    required this.segments,
    this.height = 10,
    this.duration = const Duration(milliseconds: 750),
  });

  final List<SpendSegment> segments;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.amount > 0).toList(growable: false);
    final total = visible.fold<double>(0, (sum, s) => sum + s.amount);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final isDark = context.isDark;

    final controller = useAnimationController(
      duration: duration,
      initialValue: animate ? 0 : 1,
    );

    useEffect(() {
      if (animate) controller.forward();
      return null;
    }, const []);

    final t = Curves.fastOutSlowIn.transform(
      useAnimation(controller).clamp(0.0, 1.0),
    );

    final track = Container(
      height: height,
      decoration: BoxDecoration(
        color: context.tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: context.tokens.border.withValues(alpha: 0.6)),
      ),
    );

    // Nothing spent yet: the bare track keeps the card's structure on day one.
    if (total <= 0) return track;

    return RepaintBoundary(
      child: Stack(
        children: [
          track,
          ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < visible.length; i++)
                    Expanded(
                      flex: (visible[i].amount / total * 1000).round().clamp(
                        1,
                        1000,
                      ),
                      child: _Segment(
                        color: visible[i].color,
                        // A hairline of the track between neighbours reads as
                        // a divider without breaking the single outline.
                        gap: i == visible.length - 1 ? 0 : 1.5,
                        glow: isDark,
                        height: height,
                      ),
                    ),
                  // Eats the remaining width while the bar grows, which is what
                  // makes it sweep from the leading edge rather than fade in.
                  if (t < 1)
                    Expanded(
                      flex: ((1 - t) * 1000).round().clamp(1, 1000),
                      child: const SizedBox(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One run of the bar. Square by construction — the parent's single
/// `ClipRRect` supplies the rounded tips.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.color,
    required this.gap,
    required this.glow,
    required this.height,
  });

  final Color color;
  final double gap;
  final bool glow;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.only(end: gap),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            color.withValues(alpha: 0.62),
            color,
            Color.alphaBlend(Colors.white.withValues(alpha: 0.32), color),
          ],
          stops: const [0, 0.72, 1],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        // Specular sheen along the top edge, the same device the maintenance
        // bar uses to stop a flat fill looking painted on.
        child: Container(
          height: height * 0.32,
          margin: EdgeInsetsDirectional.only(top: height * 0.16),
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
