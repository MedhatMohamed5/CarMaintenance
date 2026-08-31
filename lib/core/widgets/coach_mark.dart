import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_durations.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// How the spotlight is cut around a target.
enum CoachHoleShape {
  /// A rounded rectangle — cards, rows, bars.
  rounded,

  /// A full circle, sized to the target's shorter side. For a round target —
  /// an avatar, an icon button — a rounded rectangle leaves four lit corners
  /// that read as a mistake rather than as a highlight.
  circle,
}

/// One stop on a guided tour: a widget to point at, and what to say about it.
///
/// Both halves of the copy are l10n keys, never literal text — the same
/// contract [GuidanceTip] follows, for the same reason: a tour written in one
/// language is a tour half the users cannot read.
@immutable
class CoachStep {
  const CoachStep({
    required this.targetKey,
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
    required this.color,
    this.shape = CoachHoleShape.rounded,
    this.inflate = 8,
  });

  /// Attached to the real widget, wherever it lives. The tour never has to know
  /// which screen owns it — only that it is currently on screen.
  final GlobalKey targetKey;

  final String titleKey;
  final String bodyKey;
  final IconData icon;

  /// Accent for the ring and the bubble's badge. Using the target's own colour
  /// is what ties the two together across the scrim.
  final Color color;

  final CoachHoleShape shape;

  /// Breathing room between the target's bounds and the cut. Zero would trace
  /// the widget exactly, which reads as a border rather than as a spotlight.
  final double inflate;
}

/// Runs [steps] as a spotlight tour over whatever is currently on screen.
///
/// **Steps whose target is not mounted are dropped before the tour starts.**
/// Half this dashboard renders nothing when it has nothing to say — no parking
/// pin, no notes, no alerts — so pointing at a widget that is not there would
/// spotlight empty space. Filtering here means a step can be written for a card
/// that only sometimes exists.
///
/// Returns when the tour is dismissed, finished or skipped; the caller cannot
/// tell the two apart on purpose, because either way the user is done being
/// shown around.
Future<void> showCoachMarks(
  BuildContext context, {
  required List<CoachStep> steps,
}) {
  final live = [
    for (final step in steps)
      if (step.targetKey.currentContext != null) step,
  ];
  if (live.isEmpty) return Future<void>.value();

  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_CoachMarkRoute(steps: live));
}

/// A route rather than an `OverlayEntry`, for one reason: the system back
/// button.
///
/// An overlay entry sits outside the navigator, so back would fall through to
/// the shell — which on the Home tab answers with "press back again to exit".
/// A route pops itself, which is exactly what a back press during a tour should
/// mean.
///
/// [PopupRoute] is already non-opaque and keeps the screen below alive and
/// painted, which is the whole premise of a spotlight.
class _CoachMarkRoute extends PopupRoute<void> {
  _CoachMarkRoute({required this.steps});

  final List<CoachStep> steps;

  /// Null, not a colour: the scrim is painted by the overlay itself, because it
  /// needs a hole in it.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => AppDurations.expand;

  @override
  Duration get reverseTransitionDuration => AppDurations.routeExit;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _CoachMarkOverlay(steps: steps);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    // A lazy view, not a `CurvedAnimation`: this builder runs on every frame of
    // the transition and a `CurvedAnimation` attaches a listener per call. Same
    // rule the page transitions in `app_router.dart` follow.
    opacity: CurveTween(curve: Curves.easeOut).animate(animation),
    child: child,
  );
}

class _CoachMarkOverlay extends StatefulWidget {
  const _CoachMarkOverlay({required this.steps});

  final List<CoachStep> steps;

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: AppDurations.expand,
    value: 1,
  );

  /// The lit rectangle, as a lazy view over [_move]. Null until the first
  /// target has been measured.
  Animation<Rect?>? _hole;

  int _index = 0;

  /// Guards a second [_focus] starting while the first is still awaiting a
  /// scroll. A double tap on Next is otherwise enough to leave two passes
  /// racing over the same field.
  bool _moving = false;

  /// Where the screen underneath was scrolled to before the tour moved it, so
  /// the tour can put it back.
  ///
  /// Reaching a card below the fold means scrolling the list the user is
  /// standing on. Ending four cards further down than they started is the
  /// small, specific disorientation that makes a tour feel like something that
  /// happened *to* them.
  ScrollPosition? _restorePosition;
  double _restoreOffset = 0;

  @override
  void initState() {
    super.initState();
    // After the first frame: the route is mounted but nothing below it has been
    // laid out against it yet, and a target's rect only means something once it
    // has.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus(0));
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  /// Moves the spotlight to [index], stepping past anything that has since gone
  /// off screen or been unmounted.
  Future<void> _focus(int index, {int direction = 1}) async {
    if (_moving) return;
    _moving = true;
    try {
      var cursor = index;
      while (cursor >= 0 && cursor < widget.steps.length) {
        final rect = await _resolve(widget.steps[cursor]);
        if (!mounted) return;
        if (rect != null) {
          // The very first step grows out of its own centre; every later one
          // slides from wherever the light already was.
          final from =
              _hole?.value ??
              Rect.fromCenter(center: rect.center, width: 0, height: 0);
          setState(() {
            _index = cursor;
            _hole = _move.drive(
              RectTween(
                begin: from,
                end: rect,
              ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
            );
          });
          _move.forward(from: 0);
          return;
        }
        cursor += direction;
      }
      _finish();
    } finally {
      _moving = false;
    }
  }

  /// Scrolls a target into view if it lives in a list, then measures it.
  ///
  /// Returns null when the step cannot be shown: the widget is gone, has no
  /// size yet, or sits outside the viewport even after the scroll.
  Future<Rect?> _resolve(CoachStep step) async {
    final target = step.targetKey.currentContext;
    if (target == null) return null;

    // Noted once, from the first step that turns out to live in a list — which
    // is before anything has moved.
    if (_restorePosition == null) {
      final position = Scrollable.maybeOf(target)?.position;
      if (position != null && position.hasPixels) {
        _restorePosition = position;
        _restoreOffset = position.pixels;
      }
    }

    // A no-op when there is no `Scrollable` above the target, which is the case
    // for the navigation bar and the app-bar actions.
    await Scrollable.ensureVisible(
      target,
      alignment: 0.35,
      duration: AppDurations.expand,
      curve: Curves.fastOutSlowIn,
    );
    if (!mounted) return null;

    // The scroll settles layout; the rect is only correct after the frame that
    // applied it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;

    final box = step.targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;

    final rect = (box.localToGlobal(Offset.zero) & box.size).inflate(
      step.inflate,
    );
    final screen = (Offset.zero & MediaQuery.sizeOf(context)).deflate(4);
    if (!rect.overlaps(screen)) return null;

    final visible = rect.intersect(screen);
    if (visible.width <= 8 || visible.height <= 8) return null;
    return visible;
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index >= widget.steps.length - 1) {
      _finish();
    } else {
      _focus(_index + 1);
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    _focus(_index - 1, direction: -1);
  }

  void _finish() {
    if (!mounted) return;
    _rewind();
    Navigator.of(context).maybePop();
  }

  /// Puts the screen underneath back where the driver left it.
  void _rewind() {
    final position = _restorePosition;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    final target = _restoreOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - target).abs() < 1) return;
    position.animateTo(
      target,
      duration: AppDurations.expand,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final padding = MediaQuery.paddingOf(context);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _move,
        builder: (context, _) {
          final hole = _hole?.value ?? Rect.zero;
          final radius = switch (step.shape) {
            CoachHoleShape.circle => hole.shortestSide / 2,
            CoachHoleShape.rounded => 18.0,
          };

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  // Anywhere on the scrim advances. The buttons say so
                  // explicitly, but tap-to-continue is what people reach for
                  // first and it should not feel dead.
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole,
                      radius: radius,
                      accent: step.color,
                      scrim: Colors.black.withValues(
                        alpha: context.isDark ? 0.74 : 0.58,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _BubbleLayout(hole: hole, safe: padding),
                  child: _CoachBubble(
                    step: step,
                    index: _index,
                    total: widget.steps.length,
                    onBack: _index == 0 ? null : _back,
                    onNext: _next,
                    onSkip: _finish,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The scrim, with a hole in it and a ring around the hole.
///
/// One `Path.combine` rather than four rectangles laid around the target: the
/// cut has rounded corners, and stitching those out of rectangles is where this
/// kind of overlay usually starts leaking light.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.accent,
    required this.scrim,
  });

  final Rect hole;
  final double radius;
  final Color accent;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);

    if (hole.isEmpty) {
      canvas.drawPath(full, Paint()..color = scrim);
      return;
    }

    final cut = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, Path()..addRRect(cut)),
      Paint()..color = scrim,
    );

    // Glow first, hairline over it — the same two-pass accent every card in the
    // app already uses, so the spotlight reads as the same material.
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = accent.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole ||
      old.radius != radius ||
      old.accent != accent ||
      old.scrim != scrim;
}

/// Places the bubble under the spotlight, or over it when there is no room
/// below.
///
/// A [SingleChildLayoutDelegate] rather than arithmetic in a build method,
/// because the decision needs the bubble's *measured* height — which depends on
/// how the copy wraps, and Arabic and English do not wrap the same.
class _BubbleLayout extends SingleChildLayoutDelegate {
  const _BubbleLayout({required this.hole, required this.safe});

  final Rect hole;
  final EdgeInsets safe;

  /// Gap between the lit edge and the bubble.
  static const double _gap = 18;

  /// Margin from the screen edges, matching the app's 16 pt gutter.
  static const double _margin = 16;

  /// A line of body copy stops being readable long before it is 400 pt wide,
  /// and on a tablet the bubble would otherwise stretch the full width.
  static const double _maxWidth = 420;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = constraints.maxWidth - _margin * 2;
    return BoxConstraints.loose(
      Size(
        available > _maxWidth ? _maxWidth : available,
        constraints.maxHeight - safe.top - safe.bottom - _margin * 2,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minTop = safe.top + _margin;
    final maxTop = size.height - safe.bottom - _margin - childSize.height;

    final below = hole.bottom + _gap;
    final above = hole.top - _gap - childSize.height;

    // Below when it fits, above when it does not, and — for a target tall
    // enough that neither fits — pushed to whichever end has more room.
    final double top;
    if (below <= maxTop) {
      top = below;
    } else if (above >= minTop) {
      top = above;
    } else {
      top = hole.center.dy < size.height / 2 ? maxTop : minTop;
    }

    final maxLeft = size.width - childSize.width - _margin;

    return Offset(
      (hole.center.dx - childSize.width / 2).clamp(
        _margin,
        maxLeft < _margin ? _margin : maxLeft,
      ),
      top.clamp(minTop, maxTop < minTop ? minTop : maxTop),
    );
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.hole != hole || old.safe != safe;
}

/// What the tour actually says, in the app's own card material.
///
/// Opaque rather than a [GlassCard]: a blurred panel over a 70 % scrim has
/// almost nothing left to blur, and the text is the whole point here.
class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  final CoachStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final last = index == total - 1;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: step.color.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(icon: step.icon, color: step.color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.raw(step.titleKey),
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.raw(step.bodyKey),
            style: context.text.bodySmall?.copyWith(
              color: tokens.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          // The controls wrap rather than overflow: three buttons and a
          // progress row do not fit one line at the largest text scale the app
          // allows, and "Next" is the one control that must never be clipped.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _Dots(count: total, index: index, color: step.color),
              ),
              if (onBack != null)
                TextButton(
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                  ),
                  child: Text(l10n.raw('tourBack')),
                ),
              if (!last)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                  ),
                  child: Text(l10n.raw('tourSkip')),
                ),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: step.color,
                  // The accents are all light, saturated colours; black is the
                  // only label that stays legible on every one of them.
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: Text(l10n.raw(last ? 'tourDone' : 'tourNext')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progress as position rather than as a number. "3 / 6" is a fact the reader
/// has to parse; a filled dot in a row of six is one they can see.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: AppDurations.stateChange,
          curve: Curves.fastOutSlowIn,
          margin: const EdgeInsetsDirectional.only(end: 5),
          width: i == index ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: i == index
                ? color
                : context.tokens.textSecondary.withValues(alpha: 0.4),
          ),
        ),
    ],
  );
}
