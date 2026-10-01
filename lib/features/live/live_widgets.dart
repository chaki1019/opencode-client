import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/event_stream.dart';
import 'live_providers.dart';

/// A thin bar shown while the live event stream is reconnecting, so users
/// know updates may be delayed.
class LiveStatusBanner extends ConsumerWidget implements PreferredSizeWidget {
  const LiveStatusBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(eventStreamStatusProvider).value;
    if (status != EventStreamStatus.reconnecting) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: preferredSize.height,
      color: scheme.tertiaryContainer,
      alignment: Alignment.center,
      child: Text(
        'サーバーに再接続しています…',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

/// A small spinner marking a session the server is working on.
class SessionBusyIndicator extends StatelessWidget {
  const SessionBusyIndicator({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}
