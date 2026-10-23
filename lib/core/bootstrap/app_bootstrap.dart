import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../features/dealers/data/repositories/user_workshop_repository_impl.dart';
import '../../features/dealers/domain/entities/dealer_ratings.dart';
import '../../features/dealers/domain/repositories/user_workshop_repository.dart';
import '../remote/remote_config_service.dart';
import '../constants/app_durations.dart';
import '../constants/app_flavor.dart';
import '../firebase/crash_reporter.dart';
import '../firebase/firebase_bootstrap.dart';
import '../firebase/firebase_config.dart';
import '../platform/platform_capabilities.dart';
import '../platform/reminder_notifier.dart';
import '../storage/hive_boxes.dart';
import '../storage/preferences_store.dart';
import '../theme/app_theme.dart';
import '../widgets/vehicle_care_logo.dart';
import '../localization/app_localizations.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.preferences,
    required this.userWorkshops,
    this.reminderNotifier,
  });

  final PreferencesStore preferences;
  final UserWorkshopRepository userWorkshops;
  final ReminderNotifier? reminderNotifier;
}

/// Everything the app needs before the first real screen can be trusted.
///
/// Kept out of `main` so the work happens *behind* the branded splash rather
/// than in front of a blank window: `runApp` fires immediately, the splash
/// paints, and this runs underneath it.
class AppBootstrap {
  const AppBootstrap._();

  /// Opens storage, seeds reference data, wires the backend and notifications,
  /// and warms the logo painter.
  ///
  /// Every step that can fail without stopping the app is caught individually:
  /// no notification permission and no Firebase project are normal states, and
  /// neither is a reason to hold the user on a splash screen.
  ///
  /// **Every step is bounded on its own.** One ceiling over the whole run used
  /// to stand in for that, and it could not say which step had hung — and a
  /// single slow optional step was enough to fail the launch outright. Now an
  /// optional step that overruns [_stepTimeout] is reported by name and
  /// skipped, and only storage, which the app cannot run without, can still
  /// stop it.
  static Future<AppBootstrapResult> run() async {
    await _guard('dates-ar', () => initializeDateFormatting('ar'));
    await _guard('dates-en', () => initializeDateFormatting('en'));

    if (!kIsWeb) {
      await _guard(
        'orientation',
        () => SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]),
      );
    }

    // Storage is the one step with no fallback: without it there is no app.
    // Still bounded — a platform channel that never answers, storage on a
    // broken volume, would otherwise leave the splash spinning with no way
    // out. Failing loudly, with a retry, beats hanging silently.
    await HiveBoxes.init().timeout(_storageTimeout);
    final prefs = await PreferencesStore.create().timeout(_storageTimeout);

    // **Nothing is seeded into storage any more.** The standard directory is
    // admin-defined and comes from Remote Config, which keeps its own on-disk
    // copy and falls back to the values compiled into the app. All this store
    // holds is what the driver added themselves.
    //
    // The purge clears rows left behind by the version that did write the
    // standard list here; without it every stale published row would appear a
    // second time beside the live one.
    final UserWorkshopRepository userWorkshops = UserWorkshopRepositoryImpl();
    await _guard(
      'salvage-ratings',
      () => _salvageLegacyRatings(userWorkshops, prefs),
    );

    // Always initialised where the platform supports it, rather than behind a
    // stored preference: the app cannot know whether anyone is signed in until
    // Firebase itself has resolved the persisted session, so waiting for a
    // setting to say "yes" meant a returning user launched signed-out and only
    // reconnected after they went looking for a toggle.
    //
    // Skipped rather than attempted-and-caught on a platform the project was
    // never configured for. Desktop is a normal place to run this app during
    // development, and "no Firebase here" is a state, not a failure.
    {
      final options = FirebaseConfig.optionsOrNull;
      // The dev flavor stays local-only on purpose.
      if (options != null && !AppFlavor.isDev) {
        await _guard(
          'firebase-init',
          () => FirebaseBootstrap.tryInitialize(options: options),
        );
        // Registers the in-app defaults and activates whatever is already on
        // disk, so the first frame has real values. The network fetch runs
        // later, off the splash — see `RemoteDefaultsNotifier`.
        await _guard('remote-config', RemoteConfigService.init);
      }
    }

    // Initialised here, but **the permission is not asked for here**. On
    // Android 13+ asking shows a system dialog, and the request does not
    // complete until the driver answers it — so a driver who ignored it, or
    // switched away, held the whole launch until the ceiling failed it and
    // was left on an error screen. The app asks once its first screen is up;
    // see `VehicleCareApp`.
    ReminderNotifier? reminderNotifier;
    if (AppPlatform.supportsLocalNotifications) {
      await _guard('notifications', () async {
        final notifier = createReminderNotifier();
        await notifier.init();
        reminderNotifier = notifier;
      });
    }

    return AppBootstrapResult(
      preferences: prefs,
      userWorkshops: userWorkshops,
      reminderNotifier: reminderNotifier,
    );
  }

  /// Rasterises the logo once while the splash is still up, so the dashboard's
  /// app bar and the vehicle cards do not each pay for the first paint of a
  /// complex `CustomPainter`.
  static Future<void> precacheAssets(BuildContext context) async {
    await _guard('precache', () async {
      final recorder = ui.PictureRecorder();
      const VehicleCareLogoPainter().paint(
        Canvas(recorder),
        const Size.square(96),
      );
      recorder.endRecording().dispose();
    });
  }

  /// Clears the stale standard rows and keeps the ratings they were carrying.
  ///
  /// Existing entries win: a rating already in the new map was given after the
  /// upgrade and is newer than anything the old row held.
  static Future<void> _salvageLegacyRatings(
    UserWorkshopRepository workshops,
    PreferencesStore prefs,
  ) async {
    final salvaged = await workshops.purgeLegacyStandardRows();
    if (salvaged.isEmpty) return;

    final raw = prefs.dealerRatings;
    final existing = DealerRatings.fromJson(
      raw == null || raw.isEmpty ? null : jsonDecode(raw),
    );

    var merged = existing;
    for (final entry in salvaged.entries) {
      if (existing.ratingOf(entry.key) != null) continue;
      merged = merged.withRating(entry.key, entry.value);
    }
    await prefs.setDealerRatings(jsonEncode(merged.toJson()));
  }

  /// Ceiling on one optional step. Each normally finishes in well under a
  /// second; this only catches one that never will.
  static const Duration _stepTimeout = Duration(seconds: 6);

  /// Ceiling on each storage open — the only steps that fail the launch.
  static const Duration _storageTimeout = Duration(seconds: 20);

  /// Runs an optional step, bounded by [_stepTimeout].
  ///
  /// A step that overruns is abandoned, not cancelled: Dart cannot stop a
  /// future, so it may still finish later. Whatever it would have handed back
  /// is simply not used, and the feature behind it runs degraded this launch.
  static Future<void> _guard(String name, Future<void> Function() step) async {
    try {
      await step().timeout(_stepTimeout);
    } on Object catch (error, stack) {
      // Never fatal: a degraded feature beats a stuck splash.
      //
      // **But no longer silent.** Every one of these is a feature quietly not
      // working — no reminders, no backend, stale remote defaults — on a
      // device nobody is watching a console attached to. Swallowing the error
      // is the right call for the splash; swallowing the *knowledge* of it
      // meant a driver whose reminders never fired looked identical, from
      // here, to one who had turned them off.
      debugPrint('Bootstrap step failed ($name): $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
      CrashReporter.recordError(
        error,
        stack,
        reason: 'bootstrap step failed: $name',
        tags: {'phase': 'bootstrap', 'step': name},
      );
    }
  }
}

/// Holds the branded splash until [AppBootstrap] finishes, then cross-fades to
/// [builder]'s result.
///
/// The splash is shown for at least [minimumDuration] so a fast device does not
/// flash the brand for two frames, and the fade is what removes the hard cut
/// between splash and dashboard.
class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({
    super.key,
    required this.splash,
    required this.builder,
    required this.appearance,
    this.minimumDuration = const Duration(milliseconds: 900),
    this.fadeDuration = AppDurations.stateChange,
  });

  final Widget splash;
  final Widget Function(BuildContext context, AppBootstrapResult result)
  builder;

  /// Language and theme read before the first frame, so the failure screen
  /// speaks the same language as the splash it replaces.
  final AppearancePreference appearance;

  final Duration minimumDuration;
  final Duration fadeDuration;

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  AppBootstrapResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // The floor and the work run together: the splash lasts whichever takes
      // longer, never their sum.
      // No ceiling here any more: every step inside the run carries its own,
      // so the run as a whole cannot hang.
      final results = await Future.wait([
        AppBootstrap.run(),
        Future<void>.delayed(widget.minimumDuration),
      ]);
      if (!mounted) return;

      await AppBootstrap.precacheAssets(context);
      if (!mounted) return;

      setState(() => _result = results.first as AppBootstrapResult);
    } on Object catch (error, stack) {
      // The app did not start. Fatal in the sense that matters: the driver is
      // looking at an error screen rather than their dashboard.
      CrashReporter.recordError(
        error,
        stack,
        reason: 'bootstrap failed',
        tags: {'phase': 'bootstrap', 'step': 'gate'},
        fatal: true,
      );
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  /// Back to the splash and once more from the top.
  ///
  /// Safe to repeat: storage skips boxes already open, and Firebase, Remote
  /// Config and notifications each skip work they have already done.
  void _retry() {
    setState(() => _error = null);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return AnimatedSwitcher(
      duration: widget.fadeDuration,
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.decelerate,
      // Cross-fade in place: the outgoing splash must not slide or resize, or
      // the handover reads as a second screen rather than a reveal.
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: switch ((result, _error)) {
        (final AppBootstrapResult bootstrap, _) => KeyedSubtree(
          key: const ValueKey('app'),
          child: widget.builder(context, bootstrap),
        ),
        (_, final Object error) => KeyedSubtree(
          key: const ValueKey('failed'),
          child: _BootstrapFailed(
            error: error,
            appearance: widget.appearance,
            onRetry: _retry,
          ),
        ),
        _ => KeyedSubtree(key: const ValueKey('splash'), child: widget.splash),
      },
    );
  }
}

/// Storage refused to open. Rare, and far better than a splash that spins for
/// ever.
///
/// The raw error names the storage engine and its file paths, so it goes to the
/// log rather than the screen; the user gets a plain sentence and a retry.
///
/// **Carries its own localisations, like the splash.** It used to build a bare
/// `MaterialApp`, so `AppLocalizations.of` found nothing and threw — in a
/// release build a grey screen, on the one path where the driver most needed
/// to be told something.
class _BootstrapFailed extends StatelessWidget {
  const _BootstrapFailed({
    required this.error,
    required this.appearance,
    required this.onRetry,
  });

  final Object error;
  final AppearancePreference appearance;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    debugPrint('Bootstrap failed: $error');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(arabic: appearance.locale.languageCode == 'ar'),
      darkTheme: AppTheme.dark(arabic: appearance.locale.languageCode == 'ar'),
      themeMode: appearance.themeMode,
      locale: appearance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        // A context below the `MaterialApp`, where the delegates live.
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40),
                    const SizedBox(height: 14),
                    Text(
                      l10n.somethingWentWrong,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.raw('retry')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
