import 'package:flutter/material.dart';

/// Where a floating action button sits, decided in one place.
///
/// **Why not `FloatingActionButtonLocation.endFloat`.** The default `endFloat`
/// lifts the button by `ScaffoldPrelayoutGeometry.minViewPadding.bottom`, which
/// the shell overrides to the floating navigation bar's full height so screen
/// content clears the bar. That is right for content and wrong for the button:
/// the bar's height was applied on top of Flutter's own
/// `kFloatingActionButtonMargin`, and on a device with a gesture inset the
/// system padding was counted inside the override as well — so the button
/// floated well above the bar instead of resting just over it.
///
/// This computes the offset from a single explicit [bottomInset] and ignores
/// `minViewPadding` entirely, so nothing can be counted twice no matter what
/// the enclosing shell injects. Every screen gets the same gap on every device
/// and in both orientations.
class AppFabLocation extends StandardFabLocation with FabEndOffsetX {
  const AppFabLocation({required this.bottomInset, this.gap = _defaultGap});

  /// Everything the button has to clear: the floating navigation bar inside
  /// the shell, or the plain system inset on a screen outside it.
  ///
  /// Build it with [AppFab.insetOf], which reads whichever of the two applies.
  final double bottomInset;

  /// Breathing room between the button and whatever is below it.
  ///
  /// Slightly tighter than Flutter's 16 pt `kFloatingActionButtonMargin`: the
  /// button sits over a floating bar that already carries its own margin, and
  /// stacking both reads as a gap rather than a hover.
  ///
  /// Change this and `ScrollGutter.fab` moves with it — see the note there.
  final double gap;

  static const double _defaultGap = 12;

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final contentBottom = scaffoldGeometry.contentBottom;
    final keyboard = scaffoldGeometry.minInsets.bottom;

    // With the keyboard up the bar is behind it, so the only thing to clear is
    // the keyboard itself — which `contentBottom` has already accounted for.
    final clearance = keyboard > 0 ? gap : bottomInset + gap;
    var y = contentBottom - fabHeight - clearance - adjustment;

    // Never sit under a snackbar or an open bottom sheet.
    final snackBar = scaffoldGeometry.snackBarSize.height;
    if (snackBar > 0) {
      y = _lower(y, contentBottom - snackBar - fabHeight - gap);
    }

    final sheet = scaffoldGeometry.bottomSheetSize.height;
    if (sheet > 0) {
      y = _lower(y, contentBottom - sheet - fabHeight / 2);
    }

    return y;
  }

  static double _lower(double a, double b) => a < b ? a : b;

  @override
  String toString() => 'AppFabLocation(bottomInset: $bottomInset, gap: $gap)';
}

/// Entry point for screens: `floatingActionButtonLocation: AppFab.of(context)`.
class AppFab {
  const AppFab._();

  /// What the button must clear on this screen.
  ///
  /// Inside the shell `padding.bottom` is the navigation bar's total height,
  /// because the shell injects it there; on a root-navigator screen it is the
  /// plain system inset. One expression covers both, which is why no screen
  /// needs to know whether it is inside the shell.
  static double insetOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  static FloatingActionButtonLocation of(BuildContext context) =>
      AppFabLocation(bottomInset: insetOf(context));
}
