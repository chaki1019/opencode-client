import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Makes the iOS status-bar tap scroll a reversed list to its oldest loaded
/// item. [Scaffold] scrolls its primary controller to offset 0 on that tap,
/// which in a reversed list is the newest end.
///
/// [builder] gets the controller to give the list. It runs under a
/// [PrimaryScrollController] that only answers the tap, so the scaffold
/// body should opt out of inheriting it with [PrimaryScrollController.none].
/// [onArrived] runs once the scroll reaches the oldest end, since loading
/// more on the way there is held back (see
/// [TranscriptScrollController.scrollingToOldest]).
class StatusBarScrollsToOldest extends StatefulWidget {
  const StatusBarScrollsToOldest({
    super.key,
    required this.builder,
    this.onArrived,
  });

  final Widget Function(
    BuildContext context,
    TranscriptScrollController controller,
  )
  builder;
  final VoidCallback? onArrived;

  @override
  State<StatusBarScrollsToOldest> createState() =>
      _StatusBarScrollsToOldestState();
}

class _StatusBarScrollsToOldestState extends State<StatusBarScrollsToOldest>
    with TickerProviderStateMixin {
  late final _list = TranscriptScrollController(vsync: this);
  late final _proxy = _ToOldestEnd(this);

  @override
  void dispose() {
    _proxy.dispose();
    _list.dispose();
    super.dispose();
  }

  Future<void> _scrollToOldest(Duration duration, Curve curve) async {
    final arrived = await _list.scrollToOldest(
      duration: duration,
      curve: curve,
    );
    if (arrived && mounted) widget.onArrived?.call();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _proxy,
    // Any touch hands the list back to the user.
    child: Listener(
      onPointerDown: (_) => _list.stopScrollToOldest(),
      child: widget.builder(context, _list),
    ),
  );
}

/// The transcript list's controller, able to scroll to the oldest end.
class TranscriptScrollController extends ScrollController {
  TranscriptScrollController({required this.vsync});

  final TickerProvider vsync;
  AnimationController? _toOldest;

  /// True while [scrollToOldest] runs. The far end of a lazily built list
  /// is only an estimate until its items are laid out, and loading more
  /// would move it, so callers hold off loading until the scroll arrives.
  bool get scrollingToOldest => _toOldest != null;

  /// Scrolls to [ScrollPosition.maxScrollExtent], following it as it is
  /// re-estimated and never past it. [ScrollPosition.animateTo] with the
  /// estimate overshoots far beyond the real end when the items vary in
  /// height, leaving a blank screen that then bounces back. Returns
  /// whether it got there rather than being stopped.
  Future<bool> scrollToOldest({
    required Duration duration,
    required Curve curve,
  }) async {
    if (!hasClients || _toOldest != null) return false;
    final start = position.pixels;
    final animation = AnimationController(vsync: vsync, duration: duration);
    _toOldest = animation;
    animation.addListener(() {
      if (!hasClients) return;
      final end = position.maxScrollExtent;
      final t = curve.transform(animation.value);
      position.jumpTo(math.min(start + (end - start) * t, end));
    });
    var arrived = false;
    try {
      await animation.forward().orCancel;
      arrived = hasClients;
    } on TickerCanceled {
      // Stopped by the user or disposal.
    } finally {
      _toOldest = null;
      animation.dispose();
    }
    if (arrived) position.jumpTo(position.maxScrollExtent);
    return arrived;
  }

  void stopScrollToOldest() => _toOldest?.stop(canceled: true);

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TranscriptPosition(
    this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );

  @override
  void dispose() {
    stopScrollToOldest();
    super.dispose();
  }
}

/// While scrolling to the oldest end, a jump past the end found once the
/// items are laid out is pulled back to it before anything is painted,
/// instead of showing blank space and bouncing back.
class _TranscriptPosition extends ScrollPositionWithSingleContext {
  _TranscriptPosition(
    this._controller, {
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final TranscriptScrollController _controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_controller.scrollingToOldest && pixels > maxScrollExtent) {
      correctPixels(maxScrollExtent);
      super.applyContentDimensions(minScrollExtent, maxScrollExtent);
      // Lay out again at the corrected offset.
      return false;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

/// Forwards the scaffold's "scroll to top" to the list's oldest end.
class _ToOldestEnd extends ScrollController {
  _ToOldestEnd(this._owner);

  final _StatusBarScrollsToOldestState _owner;

  @override
  bool get hasClients => _owner._list.hasClients;

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) => _owner._scrollToOldest(duration, curve);
}
