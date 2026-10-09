import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One value the UI sets and reads — a filter, a search query, the last
/// failure — as a plain Riverpod 3 `Notifier`.
///
/// **What `StateProvider` was, without the legacy import.** Riverpod 3 moved
/// `StateProvider` to `flutter_riverpod/legacy.dart` on its way out, and a
/// future release can drop it; the six places this app used it would then
/// stop compiling on an otherwise routine upgrade. Each now holds its value
/// here instead, with [set] in place of assigning to `notifier.state` from
/// outside — which `Notifier` keeps for itself.
class ValueHolder<T> extends Notifier<T> {
  ValueHolder(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}
