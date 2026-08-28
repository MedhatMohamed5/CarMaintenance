import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../theme/app_theme.dart';
import 'floating_nav_bar.dart';
import 'vehicle_care_logo.dart';

/// Corner radius of the selection indicator behind an active rail item — a
/// rounded square, not a pill/stadium, and identical for every destination.
const double _indicatorRadius = 16;

class SideNavRail extends StatelessWidget {
  const SideNavRail({
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

  static const double width = 104;

  @override
  Widget build(BuildContext context) {
    final accent = destinations[currentIndex].color;

    return Container(
      width: width,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: context.colors.surface.withValues(
          alpha: context.isDark ? 0.72 : 0.9,
        ),
        border: Border.all(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.22),
            context.tokens.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.42 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const VehicleCareLogo(size: 48),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  // Stretch, not centre: an item left to size itself would be
                  // as wide as its own label, so "سجل الصيانة" would carry a
                  // visibly wider selection indicator than "الوقود". Every
                  // item takes the full rail width so the indicator is one
                  // fixed size and the label scales inside it instead.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _RailItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        showBadge: i == badgeIndex,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends HookWidget {
  const _RailItem({
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
    final hovered = useState(false);
    final d = destination;
    final active = selected;
    final color = active
        ? d.color
        : hovered.value
        ? context.colors.onSurface
        : context.tokens.textSecondary;

    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.expand,
          curve: Curves.fastOutSlowIn,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            // Rounded-square indicator, one flat formula for every tab: the
            // destination's accent colour is the only thing that varies, so
            // "الوقود" and "سجل الصيانة" read as the same shape and weight
            // when active, never a pill.
            borderRadius: BorderRadius.circular(_indicatorRadius),
            color: active
                ? d.color.withValues(alpha: 0.20)
                : hovered.value
                ? context.tokens.surfaceHigh
                : Colors.transparent,
            border: Border.all(
              width: active ? 1.4 : 1,
              color: active
                  ? d.color.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: d.color.withValues(alpha: 0.28),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    active ? d.activeIcon : d.icon,
                    size: 22,
                    color: color,
                    shadows: active && context.isDark
                        ? [
                            Shadow(
                              color: d.color.withValues(alpha: 0.7),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  if (showBadge)
                    PositionedDirectional(
                      end: -2,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    d.label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
