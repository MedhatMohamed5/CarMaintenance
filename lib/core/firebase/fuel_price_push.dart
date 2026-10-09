import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../platform/platform_capabilities.dart';
import 'crash_reporter.dart';
import 'firebase_bootstrap.dart';

/// Pump-price pushes, sent by hand from the Firebase console when the
/// government changes the prices.
///
/// **One topic per language** — [topicFor] gives `fuel_prices_ar` and
/// `fuel_prices_en` — so a message is written once in each language and each
/// driver receives the one their app speaks. A device is subscribed to its
/// current language's topic and unsubscribed from the other, so switching the
/// app's language moves the subscription with it, and switching the reminder
/// off leaves the device on neither.
///
/// Android only for now: iOS needs an APNs key and web a service worker,
/// neither of which this project has.
class FuelPricePush {
  const FuelPricePush();

  static const String topicPrefix = 'fuel_prices_';
  static const List<String> languages = ['ar', 'en'];

  static String topicFor(String languageCode) => '$topicPrefix$languageCode';

  bool get _available => AppPlatform.isAndroid && FirebaseBootstrap.isAvailable;

  /// What the last [sync] asked for and how it went, for [diagnostics].
  static String _lastSync = 'not run';

  /// Subscribes to [languageCode]'s topic when [enabled], and to no other.
  ///
  /// Run on every launch and whenever the language or the switch changes.
  /// Subscribing is idempotent, so repeating it costs nothing. A call that
  /// fails offline is simply made again next time; any other failure is filed
  /// as a warning, because from the outside a device that never subscribed
  /// looks exactly like one that was never sent anything.
  Future<void> sync({
    required bool enabled,
    required String languageCode,
  }) async {
    if (!_available) {
      _lastSync = 'unavailable (not Android, or Firebase not initialised)';
      return;
    }
    final messaging = FirebaseMessaging.instance;
    final outcome = <String>[];
    for (final language in languages) {
      final topic = topicFor(language);
      final subscribe = enabled && language == languageCode;
      try {
        if (subscribe) {
          await messaging.subscribeToTopic(topic);
        } else {
          await messaging.unsubscribeFromTopic(topic);
        }
        outcome.add('${subscribe ? 'subscribed' : 'unsubscribed'} $topic');
      } on Object catch (error, stack) {
        outcome.add(
          '${subscribe ? 'subscribe' : 'unsubscribe'} $topic failed: $error',
        );
        if (kDebugMode) debugPrint('Fuel-price topic $topic: $error');
        // Offline is the one failure that fixes itself on the next launch.
        if (!'$error'.contains('SERVICE_NOT_AVAILABLE')) {
          CrashReporter.recordError(
            error,
            stack,
            reason:
                'fuel-price topic ${subscribe ? 'subscribe' : 'unsubscribe'} failed',
            tags: {'action': 'fuel-price-push'},
            warning: true,
          );
        }
      }
    }
    _lastSync = '${DateTime.now().toIso8601String()}: ${outcome.join('; ')}';
  }

  /// Everything needed to tell why a push did not arrive, attached by hand to
  /// the Settings test event: this device's messaging token — to send it a
  /// test straight from the Firebase console, past the topics — what the last
  /// topic sync did, and whether Android lets the app show notifications.
  ///
  /// Only ever sent when the driver long-presses the Settings title.
  Future<Map<String, Object?>> diagnostics() async {
    if (!_available) return {'available': false, 'lastSync': _lastSync};
    final messaging = FirebaseMessaging.instance;
    Future<Object?> read(Future<Object?> Function() get) async {
      try {
        return await get();
      } on Object catch (error) {
        return 'error: $error';
      }
    }

    return {
      'available': true,
      'token': await read(messaging.getToken),
      'autoInitEnabled': messaging.isAutoInitEnabled,
      'permission': await read(
        () async => (await messaging.getNotificationSettings())
            .authorizationStatus
            .name,
      ),
      'lastSync': _lastSync,
    };
  }

  /// A message sent to one of the fuel-price topics — or, for a test sent to
  /// a single device, one carrying `type: fuel_prices` in its data.
  static bool isFuelPrices(RemoteMessage message) =>
      (message.from ?? '').contains(topicPrefix) ||
      message.data['type'] == 'fuel_prices';

  /// Pushes that arrive while the app is on screen. Android does not display
  /// these itself, so the app has to say something.
  Stream<RemoteMessage> get whileOpen => _available
      ? FirebaseMessaging.onMessage.where(isFuelPrices)
      : const Stream.empty();

  /// Pushes the driver tapped while the app was in the background.
  Stream<RemoteMessage> get tapped => _available
      ? FirebaseMessaging.onMessageOpenedApp.where(isFuelPrices)
      : const Stream.empty();

  /// The push that launched the app from closed, if one did.
  Future<RemoteMessage?> launchedBy() async {
    if (!_available) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message != null && isFuelPrices(message) ? message : null;
    } on Object {
      return null;
    }
  }
}
