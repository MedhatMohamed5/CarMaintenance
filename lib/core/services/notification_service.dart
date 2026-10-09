import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../firebase/crash_reporter.dart';

/// Wraps `flutter_local_notifications` behind a tiny domain-flavoured API:
/// the rest of the app asks for "remind me about this service" and never
/// touches platform channel details.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'vehicle_care_reminders',
        'Service & renewal reminders',
        channelDescription:
            'Alerts for upcoming services, part wear and document renewals',
        importance: Importance.high,
        priority: Priority.high,
        // **Built to read right whichever way the phone draws it.** The small
        // icon is a white silhouette, the only form every Android accepts in
        // the status bar; the accent tints it — and the app name — inside the
        // shade, and in the status bar too on phones that allow colour; the
        // large icon carries the full-colour logo inside the notification
        // everywhere. The large icon is one density-free PNG
        // (drawable-nodpi), for the same reason the small one is a vector.
        color: accent,
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
      );

  /// The app's cyan, as the notification accent. Mirrored for Firebase pushes
  /// by `notification_accent` in res/values/colors.xml.
  static const Color accent = Color(0xFF22D3EE);

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));
    } on Object catch (e, stack) {
      // Fall back to UTC — a reminder an hour off beats no reminder at all.
      // Reported because every reminder this device schedules from here on is
      // against the wrong clock, and nothing downstream can tell.
      CrashReporter.recordError(
        e,
        stack,
        reason: 'device time zone unresolved; reminders scheduled in UTC',
        tags: {'action': 'schedule-reminder'},
      );
    }

    const settings = InitializationSettings(
      // A white silhouette made for the status bar (res/drawable/
      // ic_notification.xml), not launcher artwork: Android draws the icon
      // from its alpha alone. A density-free vector, because per-density PNGs
      // could not be found by name on some installs ("invalid_icon"), and the
      // bare name, as the plugin's own example passes it. Kept from the
      // resource shrinker by res/raw/keep.xml — it is named only here.
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(fuelPricesChannel);
    _ready = true;
  }

  /// Where a fuel-price push lands on Android.
  ///
  /// Created here, ahead of any message, because Firebase only displays a
  /// push on a channel that already exists; the manifest names this one as
  /// its default. Without it the push falls into Firebase's generic
  /// "Miscellaneous" channel, which a driver cannot tell apart from anything
  /// else to switch off.
  static const AndroidNotificationChannel fuelPricesChannel =
      AndroidNotificationChannel(
        'fuel_prices',
        'Fuel prices',
        description: 'When pump prices change',
        importance: Importance.high,
      );

  Future<String> _deviceTimeZone() async {
    // `flutter_local_notifications` has no timezone lookup; DateTime offset is
    // enough to pick a sane zone for the reminder scheduler.
    final offset = DateTime.now().timeZoneOffset;
    return switch (offset.inHours) {
      2 || 3 => 'Africa/Cairo',
      0 => 'UTC',
      _ => tz.local.name,
    };
  }

  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    return granted;
  }

  /// Schedules [title]/[body] for [when]. Silently skips past dates so callers
  /// can hand over a whole schedule without filtering it first.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await init();
    if (!when.isAfter(DateTime.now())) return;
    try {
      // No `uiLocalNotificationDateInterpretation` since v19: absolute time is
      // now the only interpretation, which is what this always asked for.
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (error, stack) {
      debugPrint('Notification scheduling failed: $error');
      // A reminder that never armed is the hardest bug in this app to see from
      // the outside: nothing appears, which is also what a correctly scheduled
      // reminder looks like until the day it fires.
      CrashReporter.recordError(
        error,
        stack,
        reason: 'notification scheduling failed',
      );
    }
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  Future<int> pendingCount() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Stable notification ids derived from a domain key, so re-scheduling
  /// replaces the previous reminder instead of stacking duplicates.
  static int idFor(String key) => key.hashCode & 0x7FFFFFFF;
}
