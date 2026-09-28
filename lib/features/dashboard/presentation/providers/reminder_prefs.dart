import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/reminder_category.dart';

/// What the driver chose about reminders: which kinds are on, and the hour
/// they land at.
///
/// **An hour rather than quiet hours.** Every scheduled reminder in the app
/// lands on one daily slot, so "don't disturb me between ten and eight" only
/// ever reduces to "which hour is the slot" — and asking that directly is one
/// choice instead of two that have to agree. The two exceptions keep their own
/// times: a booking reminder is tied to its appointment, and a parking reminder
/// to the minute the driver asked for.
class ReminderPrefs extends Equatable {
  const ReminderPrefs({required this.disabled, required this.hour});

  final Set<ReminderCategory> disabled;
  final int hour;

  bool allows(ReminderCategory category) => !disabled.contains(category);

  /// The offered hours: morning, midday, evening. Few on purpose — each is a
  /// real choice, and none of them wakes anyone.
  static const List<int> hours = [9, 13, 19];

  ReminderPrefs copyWith({Set<ReminderCategory>? disabled, int? hour}) =>
      ReminderPrefs(
        disabled: disabled ?? this.disabled,
        hour: hour ?? this.hour,
      );

  @override
  List<Object?> get props => [disabled, hour];
}

class ReminderPrefsNotifier extends Notifier<ReminderPrefs> {
  @override
  ReminderPrefs build() {
    final store = ref.read(preferencesStoreProvider);
    final hour = store.reminderHour;
    return ReminderPrefs(
      disabled: {
        for (final category in ReminderCategory.toggleable)
          if (!store.reminderEnabled(category.prefKey!)) category,
      },
      hour: ReminderPrefs.hours.contains(hour)
          ? hour
          : ReminderPrefs.hours.first,
    );
  }

  Future<void> setEnabled(ReminderCategory category, bool enabled) async {
    final key = category.prefKey;
    if (key == null) return;
    final disabled = {...state.disabled};
    enabled ? disabled.remove(category) : disabled.add(category);
    state = state.copyWith(disabled: disabled);
    await ref.read(preferencesStoreProvider).setReminderEnabled(key, enabled);
  }

  Future<void> setHour(int hour) async {
    if (!ReminderPrefs.hours.contains(hour)) return;
    state = state.copyWith(hour: hour);
    await ref.read(preferencesStoreProvider).setReminderHour(hour);
  }
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(
      ReminderPrefsNotifier.new,
    );
