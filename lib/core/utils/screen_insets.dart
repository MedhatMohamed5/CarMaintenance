import 'package:flutter/widgets.dart';

/// Bottom breathing room for scrollable screens, in one place.
///
/// The shell injects the floating navigation bar's height into the body's
/// `MediaQuery.padding.bottom` and `viewPadding.bottom`, so inside a branch
/// `MediaQuery.paddingOf(context).bottom` already covers the bar *and* the
/// system gesture inset. A screen therefore only has to add what **it** floats
/// over its own content: an extended FAB, or nothing at all.
///
/// The same call is correct outside the shell — on a root-navigator modal the
/// injected value simply is not there and the inset collapses to the system
/// one — which is why every scroll view in the app can use it unconditionally.
class ScrollGutter {
  const ScrollGutter._();

  /// Space under the last item on a screen with nothing floating over it.
  static const double bare = 24;

  /// Extended FAB (48) + its margin to the edge (16) + a gap above it (16).
  static const double fab = 80;
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
}
