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

/// IDs of sessions whose last run ended in an error, as seen by this app
/// since it connected. The server keeps no such flag on the session, so a
/// failure from before the app started is not known. A new run clears it.
class FailedSessionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(connectionProvider);
    listenToServerEvents(
      ref,
      onEvent: (event) {
        final id = event.sessionId;
        if (id == null) return;
        if (event.type == 'session.execution.failed' && !state.contains(id)) {
          state = {...state, id};
        } else if (event.isExecutionStarted && state.contains(id)) {
          state = {...state}..remove(id);
        }
      },
    );
    return const {};
  }
}

final failedSessionsProvider =
    NotifierProvider<FailedSessionsNotifier, Set<String>>(
      FailedSessionsNotifier.new,
    );

/// Permission requests and questions waiting on the user in one directory,
/// as request ID to session ID. Loaded once, then kept current by events;
/// a reconnect reloads.
class WaitingRequestsNotifier extends Notifier<Map<String, String>> {
  WaitingRequestsNotifier(this.directory);

  final String directory;

  @override
  Map<String, String> build() {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const {};
    Future<void> load() async {
      try {
        final pending = await client.pendingRequestSessions(
          directory: directory,
        );
        if (ref.mounted) state = pending;
      } catch (_) {
        // Live events still mark sessions that start waiting from now on.
      }
    }

    listenToServerEvents(ref, onEvent: _onEvent, onResync: load);
    unawaited(load());
    return const {};
  }

  void _onEvent(ServerEvent event) {
    final added = waitingRequestAdded(event);
    if (added != null) {
      final (id, sessionId) = added;
      if (state[id] != sessionId) state = {...state, id: sessionId};
      return;
    }
    final settled = waitingRequestSettled(event);
    if (settled != null && state.containsKey(settled)) {
      state = {...state}..remove(settled);
      return;
    }
    // A run that stops drops whatever it was still asking.
    final sessionId = event.sessionId;
    if (event.isExecutionTerminal &&
        sessionId != null &&
        state.containsValue(sessionId)) {
      state = {...state}..removeWhere((_, s) => s == sessionId);
    }
  }
}

final waitingRequestsProvider = NotifierProvider.autoDispose
    .family<WaitingRequestsNotifier, Map<String, String>, String>(
      WaitingRequestsNotifier.new,
    );

/// The request ID and session ID a permission or question event announces.
/// Accepts both the `permission.asked` / `form.created` names and the
/// `*.v2.*` names newer servers use.
(String, String)? waitingRequestAdded(ServerEvent event) {
  final Object? request = switch (event.type) {
    'permission.asked' ||
    'permission.v2.asked' ||
    'question.v2.asked' => event.data,
    'form.created' => event.data['form'],
    _ => null,
  };
  if (request is! Map) return null;
  final id = request['id'];
  final sessionId = request['sessionID'];
  return id is String && sessionId is String ? (id, sessionId) : null;
}

/// The ID of the permission or question request [event] settles, if any.
String? waitingRequestSettled(ServerEvent event) => switch (event.type) {
  'permission.replied' ||
  'permission.v2.replied' ||
  'question.v2.replied' ||
  'question.v2.rejected' ||
  'form.replied' ||
  'form.cancelled' => (event.data['requestID'] ?? event.data['id']) as String?,
  _ => null,
};

/// What a session is doing, for the session list. Null when idle.
enum SessionActivity { waiting, running, failed }

final sessionActivityProvider = Provider.autoDispose
    .family<SessionActivity?, ({String sessionId, String directory})>((
      ref,
      key,
    ) {
      final waiting = ref.watch(
        waitingRequestsProvider(key.directory)
            .select((requests) => requests.containsValue(key.sessionId)),
      );
      if (waiting) return SessionActivity.waiting;
      if (ref.watch(
        activeSessionsProvider.select((ids) => ids.contains(key.sessionId)),
      )) {
        return SessionActivity.running;
      }
      if (ref.watch(
        failedSessionsProvider.select((ids) => ids.contains(key.sessionId)),
      )) {
        return SessionActivity.failed;
      }
      return null;
    });
