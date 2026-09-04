import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_durations.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/firebase/crash_reporter.dart';
import 'core/firebase/crash_reporting_observer.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences_store.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_splash.dart';
import 'features/dashboard/presentation/providers/reminder_scheduler.dart';
import 'features/dealers/presentation/providers/dealer_providers.dart';

/// Resolves how to paint, then paints, then initialises.
///
/// Exactly one thing is awaited before `runApp`: the stored language and theme.
/// It is a cached `SharedPreferences` read and it is what stops the splash
/// rendering in the wrong language and flipping a second later. Everything
/// heavier — storage, seed data, the backend, notifications — still runs inside
/// [AppBootstrapGate] behind the branded splash.
Future<void> main() async {
  // **Everything runs inside Sentry's zone, including the awaits above
  // `runApp`.** Font loading and the appearance read happen before the first
  // frame, so a failure in either is exactly the kind of startup crash worth
  // capturing — and a handler installed after them would miss it.
  await CrashReporter.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppFonts.ensureLoaded();
    final appearance = await PreferencesStore.restoreAppearance();
    runApp(VehicleCareBootstrap(appearance: appearance));
  });
}

/// The pre-scope shell: splash first, [ProviderScope] once the store exists.
///
/// `preferencesStoreProvider` is overridden with a real instance rather than
/// read asynchronously, which is why the scope cannot exist until the bootstrap
/// has finished.
///
/// **Each branch carries its own `MaterialApp`, and that is deliberate.** An
/// outer `MaterialApp` wrapping both would own the outermost `Navigator`, and
/// every sheet and dialog in the app opens with `useRootNavigator: true` — they
/// would mount above the [ProviderScope] and throw "No ProviderScope found" the
/// moment one read a provider. With the app branch owning the only navigator
/// once it is up, the root navigator is always inside the scope.
class VehicleCareBootstrap extends StatelessWidget {
  const VehicleCareBootstrap({super.key, required this.appearance});

  /// Language and theme read before the first frame, so the splash matches the
  /// app it is about to hand over to.
  final AppearancePreference appearance;

  @override
  Widget build(BuildContext context) {
    return AppBootstrapGate(
      splash: _SplashApp(appearance: appearance),
      builder: (context, bootstrap) => ProviderScope(
        observers: const [CrashReportingObserver()],
        overrides: [
          preferencesStoreProvider.overrideWithValue(bootstrap.preferences),
          userWorkshopRepositoryProvider.overrideWithValue(
            bootstrap.userWorkshops,
          ),
          if (bootstrap.reminderNotifier != null)
            notificationServiceProvider.overrideWithValue(
              bootstrap.reminderNotifier!,
            ),
        ],
        child: const VehicleCareApp(),
      ),
    );
  }
}

/// The splash, in the minimum shell it needs: theme, localisations and a
/// directionality, but nothing the real app will need to own later.
///
/// Its locale and theme come from the same stored values `localeProvider` and
/// `themeModeProvider` will resolve to, so the handover changes nothing on
/// screen but the content. Every string it shows is a live l10n key; nothing is
/// baked in.
class _SplashApp extends StatelessWidget {
  const _SplashApp({required this.appearance});

  final AppearancePreference appearance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appearance.themeMode,
      themeAnimationDuration: Duration.zero,
      locale: appearance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppSplash(),
    );
  }
}

class VehicleCareApp extends ConsumerStatefulWidget {
  const VehicleCareApp({super.key});

  @override
  ConsumerState<VehicleCareApp> createState() => _VehicleCareAppState();
}

class _VehicleCareAppState extends ConsumerState<VehicleCareApp> {
  @override
  void initState() {
    super.initState();
    // One pass on every launch, and it is not redundant with the listener
    // below.
    //
    // `ref.listen` fires on *change*, never on the first read. Vehicles,
    // services and part health all hydrate synchronously from the local store,
    // so on a cold start the signature is already complete the first time it is
    // read and nothing ever changes it. A driver who enables reminders and then
    // simply uses the app — without logging a fill or touching the odometer —
    // got no scheduling pass at all, and the previous run's notifications
    // expired with nothing to replace them.
    //
    // After the first frame, so the provider graph is settled before anything
    // reads it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(reminderSchedulerProvider).rescheduleAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scheduling runs from a listener, never from a provider build.
    ref.listen<int>(reminderSignatureProvider, (previous, next) {
      if (previous == next) return;
      ref.read(reminderSchedulerProvider).scheduleSoon();
    });

    return MaterialApp.router(
      title: 'Vehicle Care',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(goRouterProvider),
      themeMode: ref.watch(themeModeProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeAnimationDuration: AppDurations.stateChange,
      themeAnimationCurve: Curves.fastOutSlowIn,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const AppScrollBehavior(),
      // **`title:` alone does not hold on web.** `MaterialApp` applies it
      // once, and every subsequent route change lets the engine write the
      // current path into `document.title` — so the tab reads
      // "localhost:8099/#/workshops" instead of the app's name.
      //
      // `Title` re-asserts it on every build, and this builder rebuilds on
      // navigation because it wraps the router's `Navigator`. That makes the
      // correction happen exactly when the thing that breaks it happens.
      builder: (context, child) => Title(
        title: 'Vehicle Care',
        color: AppColors.cyan,
        child: _ClampedTextScale(child: child!),
      ),
    );
  }
}

/// Caps how far the platform text scale can stretch the layout.
///
/// **The `MediaQuery.of` call is isolated here on purpose.** `MediaQuery.of`
/// subscribes to every field of `MediaQueryData`, `viewInsets` included, and
/// this sits directly under `MaterialApp` — so having it inline in `builder`
/// rebuilt the *entire application* on every frame of the keyboard animation.
/// Confined to a leaf whose [child] is passed through unchanged,
/// `Element.update` sees an identical widget and short-circuits the subtree.
class _ClampedTextScale extends StatelessWidget {
  const _ClampedTextScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scale),
      child: RepaintBoundary(child: child),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
