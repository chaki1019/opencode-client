import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// A floating ↓ button over a reversed transcript, shown while it is
/// scrolled away from the newest end (offset 0); tapping it scrolls there.
class ScrollToNewestButton extends StatefulWidget {
  const ScrollToNewestButton({super.key, required this.controller});

  final ScrollController controller;

  /// How far from the newest end the button appears.
  static const double showAfter = 200;

  @override
  State<ScrollToNewestButton> createState() => _ScrollToNewestButtonState();
}

class _ScrollToNewestButtonState extends State<ScrollToNewestButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(ScrollToNewestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final c = widget.controller;
    final visible =
        c.hasClients && c.position.pixels > ScrollToNewestButton.showAfter;
    if (visible != _visible) setState(() => _visible = visible);
  }

  Future<void> _scroll() async {
    final position = widget.controller.position;
    // From far back, jump most of the way so the animation stays short.
    final near = position.viewportDimension * 2;
    if (position.pixels > near) position.jumpTo(near);
    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedScale(
        scale: _visible ? 1 : 0.6,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: FloatingActionButton.small(
            key: const Key('scroll-to-newest'),
            heroTag: null,
            tooltip: context.l10n.scrollToNewest,
            backgroundColor: scheme.surfaceContainerHigh,
            foregroundColor: scheme.onSurface,
            onPressed: _scroll,
            child: const Icon(Icons.arrow_downward),
          ),
        ),
      ),
    );
  }
}
