import 'reminder_notifier.dart';

class NoopReminderNotifier implements ReminderNotifier {
  const NoopReminderNotifier();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

ReminderNotifier createPlatformReminderNotifier() =>
    const NoopReminderNotifier();
