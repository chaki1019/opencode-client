import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/events/event_stream.dart';
import 'live_providers.dart';

/// A thin bar shown while the live event stream is reconnecting, so users
/// know updates may be delayed. It takes no space in the app bar and hangs
/// over the top of the content while shown, so the bar is not padded with an
/// empty strip the rest of the time.
class LiveStatusBanner extends ConsumerWidget implements PreferredSizeWidget {
  const LiveStatusBanner({super.key});

  @override
  Size get preferredSize => Size.zero;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(eventStreamStatusProvider).value;
    if (status != EventStreamStatus.reconnecting) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return OverflowBox(
      alignment: Alignment.topCenter,
      maxHeight: _height,
      child: Container(
        height: _height,
        color: scheme.tertiaryContainer,
        alignment: Alignment.center,
        child: Text(
          'サーバーに再接続しています…',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

/// A small pulsing dot marking a session the server is working on.
class SessionBusyIndicator extends StatelessWidget {
  const SessionBusyIndicator({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(child: LiveDot(size: size * 0.5)),
  );
}

/// A dot in the "running" color with a soft ring that breathes, unless the
/// platform asks for reduced motion or [pulse] is false.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8, this.color, this.pulse = true});

  final double size;

  /// Defaults to the theme's running color.
  final Color? color;

  /// False for a steady dot, such as a connection that is simply up.
  final bool pulse;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.pulse || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.of(context).running;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35 * (1 - _controller.value)),
              spreadRadius: widget.size * 0.4 * (0.5 + _controller.value),
            ),
          ],
        ),
      ),
    );
  }
}
