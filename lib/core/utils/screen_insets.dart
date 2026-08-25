import 'package:flutter/widgets.dart';

/// Scroll padding that follows the keyboard without dragging its parent along.
///
/// The padding has to change when the keyboard opens, and reading the inset
/// means rebuilding on every frame of that animation. Doing it in a screen's
/// own `build` rebuilds whatever else that method touches — provider watches,
/// list children, formatters — sixty times for one keyboard.
///
/// This confines the subscription to a leaf. [builder] receives the resolved
/// padding and is the only thing that re-runs; hand it a `child` list built
/// once by the parent and the rows themselves are never rebuilt.
class KeyboardAwareScrollPadding extends StatelessWidget {
  const KeyboardAwareScrollPadding({
    super.key,
    required this.builder,
    this.top = 8,
    this.horizontal = 16,
  });

  final Widget Function(BuildContext context, EdgeInsets padding) builder;
  final double top;
  final double horizontal;

  @override
  Widget build(BuildContext context) => builder(
    context,
    context.keyboardAwareScreenPadding(top: top, horizontal: horizontal),
  );
}

/// Bottom breathing room for scrollable screens, in one place.
///
/// The shell mounts the floating navigation bar as the Scaffold's
/// `bottomNavigationBar` under `extendBody: true`, so the framework publishes
/// the bar's laid-out height to the body as `MediaQuery.padding.bottom` — the
/// bar *and* the system gesture inset underneath it. A screen therefore only
/// has to add what **it** floats over its own content: an extended FAB, or
/// nothing at all. Nothing in the app should add the bar's height on top of
/// this; doing so counted it twice and padded every screen with dead space.
///
/// The same call is correct outside the shell — on a root-navigator modal the
/// injected value simply is not there and the inset collapses to the system
/// one — which is why every scroll view in the app can use it unconditionally.
class ScrollGutter {
  const ScrollGutter._();

  /// Space under the last item on a screen with nothing floating over it.
  static const double bare = 24;

  /// Extended FAB (48) + the gap it floats above the bar (12, matching
  /// `AppFabLocation.gap`) + a gap above the button itself (16).
  ///
  /// Kept in step with `AppFabLocation`: the button's clearance and the scroll
  /// gutter that keeps the last row out from under it are the same geometry
  /// read from two directions, and they drifted apart once already.
  static const double fab = 76;
}

extension ScreenInsets on BuildContext {
  /// Everything the shell floats over this screen, plus the system inset.
  double get shellInset => MediaQuery.paddingOf(this).bottom;

  /// Bottom padding for a scroll view. Pass `hasFab: true` on any screen that
  /// mounts a `FloatingActionButton`, so the last row clears it.
  double bottomGutter({bool hasFab = false}) =>
      (hasFab ? ScrollGutter.fab : ScrollGutter.bare) + shellInset;

  /// The standard content padding for a full-screen scroll view: a 16 pt
  /// gutter either side, a small gap under the app bar, and enough room at the
  /// bottom that nothing hides behind the navigation bar or the FAB.
  EdgeInsets screenPadding({
    double top = 8,
    double horizontal = 16,
    bool hasFab = false,
  }) => EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottomGutter(hasFab: hasFab),
  );

  /// Height of the on-screen keyboard right now, or zero when it is closed.
  ///
  /// Reading this subscribes to `viewInsets`, which changes on every frame of
  /// the keyboard animation. Depend on it only from a leaf widget, never from
  /// one that also watches providers — see [KeyboardAwareScrollPadding].
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// [screenPadding] for a screen that holds text fields.
  ///
  /// While the keyboard is up the floating navigation bar is behind it, so the
  /// gutter that reserves room for the bar is dead space — it is what leaves a
  /// band of empty scaffold between the last field and the keyboard. This drops
  /// back to plain breathing room for as long as the keyboard is open, and the
  /// Scaffold's own `resizeToAvoidBottomInset` handles the rest.
  ///
  /// Do **not** pair this with `resizeToAvoidBottomInset: false` and a manual
  /// bottom padding: that subtracts the keyboard height on top of a gutter that
  /// already accounts for the bar, and the content jumps twice as far as it
  /// should.
  EdgeInsets keyboardAwareScreenPadding({
    double top = 8,
    double horizontal = 16,
  }) => EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    keyboardInset > 0 ? ScrollGutter.bare : bottomGutter(),
  );

  /// [screenPadding] split for a `CustomScrollView`, where the header block and
  /// the lazily-built list occupy separate slivers and only the last one
  /// carries the bottom gutter.
  ///
  /// Splitting rather than padding the whole viewport keeps the side gutters on
  /// both slivers while letting the list sliver build its children lazily,
  /// which is the entire point of the split.
  ({EdgeInsets header, EdgeInsets list}) splitScreenPadding({
    double top = 8,
    double horizontal = 16,
    bool hasFab = false,
  }) => (
    header: EdgeInsets.fromLTRB(horizontal, top, horizontal, 0),
    list: EdgeInsets.fromLTRB(
      horizontal,
      0,
      horizontal,
      bottomGutter(hasFab: hasFab),
    ),
  );
}
