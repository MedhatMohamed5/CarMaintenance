import 'reminder_notifier.dart';
import 'reminder_notifier_stub.dart';

ReminderNotifier createPlatformReminderNotifier() =>
    const NoopReminderNotifier();
