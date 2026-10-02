import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps an accordion's header where it was tapped while it opens or closes.
///
/// The chat transcript is a reversed list, so a growing item keeps its bottom
/// edge and pushes its header upward. For a short [window] after a toggle,
/// height changes of the accordion are handed to the list's
/// [AnchoredScrollPhysics], which shifts the scroll offset by the same amount
/// before the frame is painted, so the item grows below the header instead.
/// Outside that window (e.g. text streaming into an open accordion) the list
/// behaves as usual. Does nothing unless the enclosing scrollable is
/// reversed and uses [AnchoredScrollPhysics].
class ExpandDownward extends StatefulWidget {
  const ExpandDownward({super.key, required this.builder});

  /// Builds the accordion; call `onExpansionChanged` when it opens or closes.
  final Widget Function(
    BuildContext context,
    ValueChanged<bool> onExpansionChanged,
  )
  builder;

  /// How long after a toggle size changes are compensated. Covers the
  /// ExpansionTile animation with some margin.
  static const window = Duration(milliseconds: 500);

  @override
  State<ExpandDownward> createState() => _ExpandDownwardState();
}

class _ExpandDownwardState extends State<ExpandDownward> {
  bool _anchoring = false;
  Timer? _timer;

  void _toggled(bool _) {
    _timer?.cancel();
    setState(() => _anchoring = true);
    _timer = Timer(ExpandDownward.window, () {
      if (!mounted) return;
      // Drop anything the list didn't get to apply.
      _anchorOf(Scrollable.maybeOf(context))?.pending = 0;
      setState(() => _anchoring = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    return _AnchorTop(
      position: _anchoring && scrollable?.axisDirection == AxisDirection.up
          ? scrollable!.position
          : null,
      child: widget.builder(context, _toggled),
    );
  }
}

/// The anchor the list is actually using. Read from the position rather than
/// the widget: a rebuilt list with new physics of the same type keeps the old
/// physics on its position.
ScrollAnchor? _anchorOf(ScrollableState? scrollable) =>
    _anchorOfPosition(scrollable?.position);

ScrollAnchor? _anchorOfPosition(ScrollPosition? position) {
  final physics = position?.physics;
  return physics is AnchoredScrollPhysics ? physics.anchor : null;
}

/// Scroll offset still owed to items that changed height this frame.
class ScrollAnchor {
  double pending = 0;
}

/// Applies [ScrollAnchor.pending] when the list's content size changes.
///
/// Going through [adjustPositionForNewDimensions] makes the viewport lay out
/// again with the shifted offset in the same frame, so the header never shows
/// in the wrong place. (Correcting the position directly from a child's
/// layout only takes effect a frame later, which reads as a jump.)
class AnchoredScrollPhysics extends ScrollPhysics {
  const AnchoredScrollPhysics({required this.anchor, super.parent});

  final ScrollAnchor anchor;

  @override
  AnchoredScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      AnchoredScrollPhysics(anchor: anchor, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final pixels = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    final delta = anchor.pending;
    if (delta == 0) return pixels;
    anchor.pending = 0;
    return (pixels + delta).clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}

class _AnchorTop extends SingleChildRenderObjectWidget {
  const _AnchorTop({required this.position, super.child});

  final ScrollPosition? position;

  @override
  _RenderAnchorTop createRenderObject(BuildContext context) =>
      _RenderAnchorTop(position);

  @override
  void updateRenderObject(BuildContext context, _RenderAnchorTop renderObject) {
    renderObject.position = position;
  }
}

class _RenderAnchorTop extends RenderProxyBox {
  _RenderAnchorTop(this.position);

  /// Set only while anchoring; null leaves the list alone.
  ScrollPosition? position;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    final last = _lastHeight;
    _lastHeight = height;
    final anchor = _anchorOfPosition(position);
    if (anchor != null && last != null) anchor.pending += height - last;
  }
}
