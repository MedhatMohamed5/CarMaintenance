import 'reminder_notifier_stub.dart'
    if (dart.library.io) 'reminder_notifier_io.dart'
    if (dart.library.js_interop) 'reminder_notifier_web.dart';

abstract interface class ReminderNotifier {
  Future<void> init();

  Future<bool> requestPermissions();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

ReminderNotifier createReminderNotifier() => createPlatformReminderNotifier();

int reminderIdFor(String key) => key.hashCode & 0x7FFFFFFF;
