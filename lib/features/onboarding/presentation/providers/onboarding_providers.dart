import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';

/// Whether the driver has already been shown around.
///
/// Persisted rather than kept in memory: a tour that replays on every cold
/// start is not an introduction, it is an obstacle.
class TourSeenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(preferencesStoreProvider).tourSeen;

  /// Called when the tour ends — finished *or* skipped. Skipping is a decision,
  /// not a postponement, and re-asking would ignore it.
  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await ref.read(preferencesStoreProvider).setTourSeen(true);
  }
}

final tourSeenProvider = NotifierProvider<TourSeenNotifier, bool>(
  TourSeenNotifier.new,
);

/// Bumped by the "show me around again" action in Settings.
///
/// **A counter, not a flag, and separate from [tourSeenProvider].** Replaying
/// has to work the second and third time as well, and clearing "seen" would
/// only re-arm the automatic first-run pass — which is suppressed while
/// Settings is on top of the dashboard, so nothing would ever happen. A counter
/// is an event: every bump is a distinct request, and the dashboard runs the
/// tour as soon as it is back on screen.
final tourReplayProvider = StateProvider<int>((ref) => 0);
