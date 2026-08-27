import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../features/dealers/data/repositories/dealer_repository_impl.dart';
import '../../features/dealers/domain/repositories/dealer_repository.dart';
import '../firebase/firebase_bootstrap.dart';
import '../firebase/firebase_config.dart';
import '../platform/platform_capabilities.dart';
import '../platform/reminder_notifier.dart';
import '../storage/hive_boxes.dart';
import '../storage/preferences_store.dart';
import '../widgets/vehicle_care_logo.dart';
import '../localization/app_localizations.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.preferences,
    required this.dealerRepository,
    this.reminderNotifier,
  });

  final PreferencesStore preferences;
  final DealerRepository dealerRepository;
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
  static Future<AppBootstrapResult> run() async {
    await _guard(() => initializeDateFormatting('ar'));
    await _guard(() => initializeDateFormatting('en'));

    if (!kIsWeb) {
      await _guard(
        () => SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]),
      );
    }

    // Storage is the one step with no fallback: without it there is no app.
    await HiveBoxes.init();
    final prefs = await PreferencesStore.create();

    final DealerRepository dealers = DealerRepositoryImpl();
    await _guard(dealers.syncSeedData);

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
      if (options != null) {
        await _guard(() => FirebaseBootstrap.tryInitialize(options: options));
      }
    }

    ReminderNotifier? reminderNotifier;
    if (AppPlatform.supportsLocalNotifications) {
      await _guard(() async {
        final notifier = createReminderNotifier();
        await notifier.init();
        if (prefs.notificationsEnabled) {
          await notifier.requestPermissions();
        }
        reminderNotifier = notifier;
      });
    }

    return AppBootstrapResult(
      preferences: prefs,
      dealerRepository: dealers,
      reminderNotifier: reminderNotifier,
    );
  }

  /// Rasterises the logo once while the splash is still up, so the dashboard's
  /// app bar and the vehicle cards do not each pay for the first paint of a
  /// complex `CustomPainter`.
  static Future<void> precacheAssets(BuildContext context) async {
    await _guard(() async {
      final recorder = ui.PictureRecorder();
      const VehicleCareLogoPainter().paint(
        Canvas(recorder),
        const Size.square(96),
      );
      recorder.endRecording().dispose();
    });
  }

  static Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stack) {
      // Never fatal: a degraded feature beats a stuck splash.
      debugPrint('Bootstrap step failed: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
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
    this.minimumDuration = const Duration(milliseconds: 900),
    this.fadeDuration = const Duration(milliseconds: 200),
    this.timeout = const Duration(seconds: 20),
  });

  final Widget splash;
  final Widget Function(BuildContext context, AppBootstrapResult result)
  builder;
  final Duration minimumDuration;
  final Duration fadeDuration;

  /// Ceiling on the whole bootstrap.
  ///
  /// A platform channel that never answers — storage on a broken volume, a
  /// plugin missing from the host — would otherwise leave the splash spinning
  /// with no way out. Failing loudly beats hanging silently.
  final Duration timeout;

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
      final results = await Future.wait([
        AppBootstrap.run().timeout(widget.timeout),
        Future<void>.delayed(widget.minimumDuration),
      ]);
      if (!mounted) return;

      await AppBootstrap.precacheAssets(context);
      if (!mounted) return;

      setState(() => _result = results.first as AppBootstrapResult);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
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
          child: _BootstrapFailed(error: error),
        ),
        _ => KeyedSubtree(key: const ValueKey('splash'), child: widget.splash),
      },
    );
  }
}

/// Storage refused to open. Rare, unrecoverable in place, and far better than a
/// splash that spins for ever.
///
/// The raw error names the storage engine and its file paths, so it goes to the
/// log rather than the screen; the user gets a plain sentence they can act on.
class _BootstrapFailed extends StatelessWidget {
  const _BootstrapFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    debugPrint('Bootstrap failed: $error');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 14),
                Text(
                  AppLocalizations.of(context).somethingWentWrong,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
