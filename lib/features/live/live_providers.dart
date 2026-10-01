import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/event_stream.dart';
import '../../core/events/server_event.dart';
import '../connection/connection_providers.dart';

/// The single event stream for the active connection, or null when
/// disconnected. Replaced (and the old one closed) on reconnect.
final eventStreamProvider = Provider<EventStream?>((ref) {
  final client = ref.watch(connectionProvider)?.client;
  if (client == null) return null;
  final stream = EventStream(
    open: (cancel) => client.openEventStream(cancelToken: cancel),
  )..start();
  ref.onDispose(stream.dispose);
  return stream;
});

final eventStreamStatusProvider = StreamProvider<EventStreamStatus>((ref) {
  final stream = ref.watch(eventStreamProvider);
  if (stream == null) return Stream.value(EventStreamStatus.stopped);
  return stream.statusChanges;
});

/// Calls [onEvent] for every server event and [onResync] whenever the stream
/// reconnects (events may have been missed) for as long as [ref] lives.
void listenToServerEvents(
  Ref ref, {
  required void Function(ServerEvent event) onEvent,
  void Function()? onResync,
}) {
  final stream = ref.watch(eventStreamProvider);
  if (stream == null) return;
  var dropped = false;
  final subscriptions = <StreamSubscription<Object?>>[
    stream.events.listen(onEvent),
    stream.statusChanges.listen((status) {
      if (status == EventStreamStatus.reconnecting) {
        dropped = true;
      } else if (status == EventStreamStatus.connected && dropped) {
        dropped = false;
        onResync?.call();
      }
    }),
  ];
  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });
}

/// IDs of sessions the server is currently working on.
class ActiveSessionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const {};
    Future<void> load() async {
      try {
        final active = await client.activeSessionIds();
        if (ref.mounted) state = active;
      } catch (_) {
        // Live events still keep the set roughly right.
      }
    }

    listenToServerEvents(
      ref,
      onEvent: (event) {
        final id = event.sessionId;
        if (id == null) return;
        if (event.isExecutionStarted && !state.contains(id)) {
          state = {...state, id};
        } else if (event.isExecutionTerminal && state.contains(id)) {
          state = {...state}..remove(id);
        }
      },
      onResync: load,
    );
    unawaited(load());
    return const {};
  }
}

final activeSessionsProvider =
    NotifierProvider<ActiveSessionsNotifier, Set<String>>(
      ActiveSessionsNotifier.new,
    );
