import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps an accordion's header where it was tapped while it opens or closes.
///
/// The chat transcript is a reversed list, so a growing item keeps its bottom
/// edge and pushes its header upward. For a short [window] after a
/// toggle, height changes of [child] are fed back into the enclosing
/// scroll position in the same layout pass, so the item grows below the
/// header instead. Outside that window (e.g. text streaming into an open
/// accordion) the list behaves as usual.
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
      if (mounted) setState(() => _anchoring = false);
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
    final reversed = scrollable?.axisDirection == AxisDirection.up;
    return _AnchorTop(
      position: _anchoring && reversed ? scrollable!.position : null,
      child: widget.builder(context, _toggled),
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
    final position = this.position;
    if (position == null || last == null || !position.hasPixels) return;
    var delta = height - last;
    if (delta == 0) return;
    // A shrinking item can't pull the list past its newest end.
    delta = math.max(delta, position.minScrollExtent - position.pixels);
    // Runs inside the viewport's layout; the viewport sees the correction
    // and lays out again with the new offset before painting.
    if (delta != 0) position.correctBy(delta);
  }
}
