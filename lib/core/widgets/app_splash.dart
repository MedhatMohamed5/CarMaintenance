import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../constants/app_durations.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'vehicle_care_logo.dart';

/// The branded first frame.
///
/// [AppSplash.gradient] is also what the native launch background is
/// configured to, so a cold start goes native-splash → Flutter-splash → app
/// on one continuous surface, with no white flash at the handover.
///
/// Stateless and provider-free: it is built before the app's own scopes are
/// guaranteed to exist, so it must not read anything but the theme.
///
/// **Layout contract.** The branding block is a `Center` sitting directly in
/// the root `Stack`, so it is centred against the full viewport and nothing
/// else can pull it off axis. The loading indicator is a separate
/// `Positioned` pinned to the bottom, deliberately *not* a sibling row or a
/// trailing column child: adding it to the branding column would shift the
/// logo upward by half the indicator's height, which is what put the mark off
/// centre before.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key, this.showProgress = true});

  /// Hidden on the very first frames so a fast start does not flash a spinner
  /// the user never had time to read. Hiding it changes nothing about the
  /// branding's position, because the two live in independent layers.
  final bool showProgress;

  /// The one gradient definition. Mirror these stops in the native launch
  /// background whenever they change.
  static const List<Color> darkStops = [
    Color(0xFF0E1420),
    AppColors.darkBackground,
    Color(0xFF0A1418),
  ];

  static const List<Color> lightStops = [
    Color(0xFFFFFFFF),
    AppColors.lightBackground,
    Color(0xFFE7F6FA),
  ];

  static LinearGradient gradient(bool isDark) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark ? darkStops : lightStops,
    stops: const [0, 0.55, 1],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient(isDark)),
          child: Stack(
            children: [
              // Accent bloom, centred on the same axis as the branding so it
              // reads as light behind the mark rather than an offset glow.
              const Positioned.fill(child: _AccentBloom()),

              // Absolute centre: no padding, no offset alignment, no row.
              const Center(child: _Branding()),

              // Its own layer, so its height never enters the centring maths.
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 48,
                child: _LoadingIndicator(visible: showProgress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radial wash behind the mark. Centred horizontally and lifted slightly to
/// sit behind the logo rather than the text.
class _AccentBloom extends StatelessWidget {
  const _AccentBloom();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            AppColors.cyan.withValues(alpha: context.isDark ? 0.16 : 0.10),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Logo, title and tagline as one centred block.
///
/// `mainAxisSize: min` keeps the column exactly as tall as its content, which
/// is what lets the enclosing `Center` place it on the true vertical midpoint.
/// The tagline's horizontal padding is symmetric, so wrapping to two lines
/// stays centred instead of drifting.
class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SplashMark(),
        const SizedBox(height: 26),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: AppFonts.apply(
            context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            l10n.raw('appTagline'),
            textAlign: TextAlign.center,
            style: AppFonts.apply(
              context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Spinner and caption, centred on the same vertical axis as the branding but
/// laid out independently of it.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDurations.expand,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                strokeCap: StrokeCap.round,
                valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
                backgroundColor: tokens.border,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.raw('splashPreparing'),
              textAlign: TextAlign.center,
              style: AppFonts.apply(
                context.text.labelSmall?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The logo, breathing.
///
/// A slow scale-and-glow pulse rather than a spinner on the mark itself: it
/// reads as "alive" without implying progress the splash cannot measure. The
/// scale is uniform about the widget's own centre, so the pulse never nudges
/// the mark off the branding axis.
class _SplashMark extends HookWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    );
    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, [controller]);
    final pulse = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn),
      [controller],
    );
    useEffect(() => pulse.dispose, [pulse]);

    return AnimatedBuilder(
      animation: pulse,
      // Built once and re-composited: the painter is complex and has no reason
      // to run again on every tick.
      child: const RepaintBoundary(child: VehicleCareLogo(size: 116)),
      builder: (context, child) {
        final t = pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.10 + 0.16 * t),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 0.97 + 0.03 * t,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }
}
