import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connection/connection_providers.dart';
import '../../core/events/event_stream.dart';
import 'live_providers.dart';

/// What a server in the background is doing, for the drawer.
class ServerActivity {
  const ServerActivity({this.running = const {}, this.finished = 0});

  /// Sessions the server is working on.
  final Set<String> running;

  /// Runs that ended since the server was last on screen.
  final int finished;
}

/// Follows a pooled server's sessions while another server is on screen.
/// Starts over, with nothing finished, whenever the server comes back on
/// screen.
class ServerActivityNotifier extends Notifier<ServerActivity> {
  ServerActivityNotifier(this.serverId);

  final String serverId;

  @override
  ServerActivity build() {
    final onScreen = ref.watch(
      connectionProvider.select((c) => c?.server.id == serverId),
    );
    final client = ref.watch(
      connectionPoolProvider.select(
        (pool) => pool[serverId]?.connection?.client,
      ),
    );
    if (onScreen || client == null) return const ServerActivity();
    final stream = ref.watch(serverEventStreamProvider(serverId));
    if (stream == null) return const ServerActivity();

    Future<void> load() async {
      try {
        final running = await client.activeSessionIds();
        if (ref.mounted) {
          state = ServerActivity(running: running, finished: state.finished);
        }
      } catch (_) {
        // Live events still keep the set roughly right.
      }
    }

    var dropped = false;
    final subscriptions = <StreamSubscription<Object?>>[
      stream.events.listen((event) {
        final id = event.sessionId;
        if (id == null) return;
        if (event.isExecutionStarted && !state.running.contains(id)) {
          state = ServerActivity(
            running: {...state.running, id},
            finished: state.finished,
          );
        } else if (event.isExecutionTerminal) {
          state = ServerActivity(
            running: {...state.running}..remove(id),
            finished: state.finished + 1,
          );
        }
      }),
      stream.statusChanges.listen((status) {
        if (status == EventStreamStatus.reconnecting) {
          dropped = true;
        } else if (status == EventStreamStatus.connected && dropped) {
          dropped = false;
          unawaited(load());
        }
      }),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });
    unawaited(load());
    return const ServerActivity();
  }
}

final serverActivityProvider =
    NotifierProvider.family<ServerActivityNotifier, ServerActivity, String>(
      ServerActivityNotifier.new,
    );

/// Keeps every pooled server's [serverActivityProvider] running, so runs
/// that end while the drawer is closed are still counted. Watched once by
/// the app.
final serverActivityKeeperProvider = Provider<void>((ref) {
  final ids = ref.watch(
    connectionPoolProvider.select((pool) => pool.keys.toSet()),
  );
  for (final id in ids) {
    ref.listen(serverActivityProvider(id), (_, _) {});
  }
});
