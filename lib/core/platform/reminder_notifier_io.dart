import '../services/notification_service.dart';
import 'platform_capabilities.dart';
import 'reminder_notifier.dart';
import 'reminder_notifier_stub.dart';

class LocalReminderNotifier implements ReminderNotifier {
  const LocalReminderNotifier();

  NotificationService get _service => NotificationService.instance;

  @override
  Future<void> init() => _service.init();

  @override
  Future<bool> requestPermissions() => _service.requestPermissions();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) => _service.schedule(
    id: id,
    title: title,
    body: body,
    when: when,
    payload: payload,
  );

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) => _service.showNow(id: id, title: title, body: body);

  @override
  Future<int> pendingCount() => _service.pendingCount();

  @override
  Future<void> cancel(int id) => _service.cancel(id);

  @override
  Future<void> cancelAll() => _service.cancelAll();
}

ReminderNotifier createPlatformReminderNotifier() =>
    AppPlatform.supportsLocalNotifications
    ? const LocalReminderNotifier()
    : const NoopReminderNotifier();
