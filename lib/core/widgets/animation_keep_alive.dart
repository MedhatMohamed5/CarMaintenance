import 'package:flutter/material.dart';

/// Holds a lazily-built sliver child alive once it has been mounted, so an
/// animation that plays on mount plays exactly once.
///
/// A `SliverList` disposes a child that scrolls past its cache extent and
/// builds it again on the way back. Anything whose "already played" state
/// lives in the element — an `AnimationController` from
/// `useAnimationController`, a `useRef` holding the value tweened from — is
/// destroyed with it, so the fill, sweep or count replays every time the user
/// scrolls back up. Keeping the element is what makes "once on mount" mean
/// once for the lifetime of the screen rather than once per appearance.
///
/// It lives in its own widget because `AutomaticKeepAliveClientMixin` needs a
/// `State`, which a `HookWidget` does not have.
///
/// Outside a sliver this is inert: with no lazy ancestor to notify there is
/// nothing to keep alive and nothing to pay for.
class AnimationKeepAlive extends StatefulWidget {
  const AnimationKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<AnimationKeepAlive> createState() => _AnimationKeepAliveState();
}

class _AnimationKeepAliveState extends State<AnimationKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
