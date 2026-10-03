import 'package:flutter/material.dart';

/// Pull-to-refresh for a reversed list: dragging up past the newest item
/// (the bottom edge) runs [onRefresh]. [RefreshIndicator] always sits at
/// the visual top, which in a reversed list is the oldest end.
///
/// Works with both clamping (overscroll notifications) and bouncing
/// (out-of-range positions) physics.
class PullUpToRefresh extends StatefulWidget {
  const PullUpToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// How far the edge must be pulled before releasing refreshes.
  static const double threshold = 80;

  @override
  State<PullUpToRefresh> createState() => _PullUpToRefreshState();
}

class _PullUpToRefreshState extends State<PullUpToRefresh> {
  double _pull = 0;
  bool _refreshing = false;

  bool _onNotification(ScrollNotification n) {
    if (n.depth != 0 || _refreshing) return false;
    final m = n.metrics;
    final dragging = switch (n) {
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (dragging) {
      var pull = _pull;
      if (n is OverscrollNotification && n.overscroll < 0) {
        // Clamping physics: the position stays at the edge.
        pull += -n.overscroll;
      } else if (n is ScrollUpdateNotification) {
        // Bouncing physics: the position moves past the edge.
        pull = m.pixels < m.minScrollExtent ? m.minScrollExtent - m.pixels : 0;
      }
      _setPull(pull);
    } else if (n is ScrollEndNotification ||
        n is ScrollUpdateNotification ||
        n is OverscrollNotification) {
      // Released: refresh if pulled far enough.
      if (_pull >= PullUpToRefresh.threshold) {
        _refresh();
      } else {
        _setPull(0);
      }
    }
    return false;
  }

  void _setPull(double pull) {
    if (pull == _pull) return;
    setState(() => _pull = pull);
  }

  Future<void> _refresh() async {
    setState(() {
      _pull = 0;
      _refreshing = true;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_pull / PullUpToRefresh.threshold).clamp(0.0, 1.0);
    final visible = _refreshing || _pull > 0;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: widget.child,
        ),
        if (visible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: Material(
                key: const Key('pull-up-indicator'),
                type: MaterialType.circle,
                elevation: 2,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: _refreshing ? null : progress,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
