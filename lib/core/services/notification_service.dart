import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
      );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));
    } catch (_) {
      // Fall back to UTC — a reminder an hour off beats no reminder at all.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

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
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(id, title, body, _details);
  }

  Future<int> pendingCount() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Stable notification ids derived from a domain key, so re-scheduling
  /// replaces the previous reminder instead of stacking duplicates.
  static int idFor(String key) => key.hashCode & 0x7FFFFFFF;
}
