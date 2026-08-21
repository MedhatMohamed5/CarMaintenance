import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/localization/app_localizations.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/platform/platform_capabilities.dart';
import 'core/platform/reminder_notifier.dart';
import 'core/storage/hive_boxes.dart';
import 'core/storage/preferences_store.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/providers/reminder_scheduler.dart';
import 'features/dealers/data/repositories/dealer_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await HiveBoxes.init();
  final prefs = await PreferencesStore.create();
  await DealerRepositoryImpl().syncSeedData();

  if (BackendMode.fromName(prefs.backendMode) == BackendMode.firestore) {
    await FirebaseBootstrap.tryInitialize();
  }

  if (AppPlatform.supportsLocalNotifications) {
    final notifier = createReminderNotifier();
    await notifier.init();
    if (prefs.notificationsEnabled) {
      await notifier.requestPermissions();
    }
  }

  runApp(
    ProviderScope(
      overrides: [preferencesStoreProvider.overrideWithValue(prefs)],
      child: const VehicleCareApp(),
    ),
  );
}

class VehicleCareApp extends ConsumerWidget {
  const VehicleCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) {
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
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
