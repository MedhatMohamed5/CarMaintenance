import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../theme/app_theme.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
}

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    this.badgeIndex,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final int? badgeIndex;

  static const double barHeight = 64;
  static const EdgeInsets margin = EdgeInsets.fromLTRB(14, 0, 14, 12);

  /// The bar publishes its own height. **Do not add a `totalHeight` helper
  /// back.** The shell mounts this as a `bottomNavigationBar` under
  /// `extendBody: true`, so the Scaffold measures the widget as laid out —
  /// [barHeight], [margin] and the `SafeArea` below — and hands that to the
  /// body as `MediaQuery.padding.bottom`. Any helper that recomputes the height
  /// would have to read `padding.bottom` to get the system inset, and inside
  /// the body that value *is* the bar, so the bar ends up counted twice.
  /// Screens read the figure through `context.shellInset`.

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = destinations[currentIndex].color;

    return SafeArea(
      top: false,
      child: Padding(
        padding: margin,
        child: SizedBox(
          height: barHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AnimatedContainer(
                duration: AppDurations.stateChange,
                curve: Curves.fastOutSlowIn,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: context.colors.surface.withValues(
                    alpha: context.isDark ? 0.82 : 0.92,
                  ),
                  border: Border.all(
                    color: Color.alphaBlend(
                      accent.withValues(alpha: 0.28),
                      tokens.border,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.45 : 0.12,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: accent.withValues(
                        alpha: context.isDark ? 0.22 : 0.10,
                      ),
                      blurRadius: 26,
                      spreadRadius: -6,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _barInset),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final n = destinations.length;
                      // Unselected tabs are icons only; the selected one takes
                      // whatever width is left, so its label never shrinks.
                      final iconWidth =
                          ((box.maxWidth - _minSelectedWidth) / (n - 1)).clamp(
                            _minIconWidth,
                            _maxIconWidth,
                          );
                      final selectedWidth = box.maxWidth - iconWidth * (n - 1);
                      double startOf(int i) => i <= currentIndex
                          ? i * iconWidth
                          : i * iconWidth + selectedWidth - iconWidth;

                      return Stack(
                        children: [
                          AnimatedPositionedDirectional(
                            duration: AppDurations.stateChange,
                            curve: Curves.fastOutSlowIn,
                            start: startOf(currentIndex),
                            top: _capsuleInset,
                            bottom: _capsuleInset,
                            width: selectedWidth,
                            child: _Capsule(color: accent),
                          ),
                          for (var i = 0; i < n; i++)
                            AnimatedPositionedDirectional(
                              duration: AppDurations.stateChange,
                              curve: Curves.fastOutSlowIn,
                              start: startOf(i),
                              top: 0,
                              bottom: 0,
                              width: i == currentIndex
                                  ? selectedWidth
                                  : iconWidth,
                              child: _NavItem(
                                destination: destinations[i],
                                selected: i == currentIndex,
                                showBadge: i == badgeIndex,
                                onTap: () => onSelected(i),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _iconSlot = 24;
const double _iconLabelGap = 6;
const double _minSelectedWidth = 112;
const double _minIconWidth = 34;
const double _maxIconWidth = 46;
const double _pillRadius = 18;
const double _barInset = 6;
const double _capsuleInset = 7;

class _Capsule extends StatelessWidget {
  const _Capsule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final glow = context.isDark;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: AppDurations.stateChange,
      builder: (context, value, _) {
        final c = value ?? color;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_pillRadius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0.10)],
            ),
            border: Border.all(color: c.withValues(alpha: 0.36)),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: glow ? 0.26 : 0),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends HookWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.showBadge,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: AppDurations.stateChange,
    );
    final bounce = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.12), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 30),
      ]).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(controller),
      [controller],
    );

    useEffect(() {
      void onStatus(AnimationStatus status) {
        if (status == AnimationStatus.completed) controller.stop();
      }

      controller.addStatusListener(onStatus);
      return () => controller.removeStatusListener(onStatus);
    }, [controller]);

    final wasSelected = useRef(selected);
    useEffect(() {
      if (selected && !wasSelected.value) controller.forward(from: 0);
      wasSelected.value = selected;
      return null;
    }, [selected]);

    final d = destination;
    final color = selected ? d.color : context.tokens.textSecondary;
    final glow = selected && context.isDark;

    final icon = ScaleTransition(
      scale: bounce,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            selected ? d.activeIcon : d.icon,
            size: 22,
            color: color,
            shadows: glow
                ? [
                    Shadow(
                      color: d.color.withValues(alpha: 0.75),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          if (showBadge)
            PositionedDirectional(
              end: -3,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    return InkResponse(
      onTap: () {
        controller.forward(from: 0);
        onTap();
      },
      radius: 40,
      containedInkWell: false,
      highlightColor: Colors.transparent,
      child: ClipRect(
        child: Center(
          child: SizedBox(
            height: _iconSlot,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (selected) ...[
                  const SizedBox(width: _iconLabelGap),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d.label,
                        maxLines: 1,
                        softWrap: false,
                        style: context.text.labelMedium?.copyWith(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
