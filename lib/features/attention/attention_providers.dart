import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/form.dart';
import '../../core/models/prompts.dart';
import '../../core/models/server_config.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import '../push/push_providers.dart';

/// Why a session is in the "needs you" list, most urgent first.
enum AttentionKind { permission, question, failed, completed }

/// A session that waits on the user: a permission or question to answer,
/// or a run that ended since anyone last looked at it.
@immutable
class AttentionItem {
  const AttentionItem({
    required this.server,
    required this.session,
    required this.kind,
  });

  final ServerConfig server;
  final Session session;
  final AttentionKind kind;

  /// Answering is the only way out of a permission or question; a finished
  /// run can just be marked as seen.
  bool get dismissible =>
      kind == AttentionKind.completed || kind == AttentionKind.failed;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(
    (session.time.idle ?? session.time.updated).round(),
  );
}

/// Finished runs older than this are left out: sessions from before the
/// server tracked what was seen have never been marked, and nobody wants
/// last month's runs in the list.
const unseenRunWindow = Duration(days: 3);

/// How many of the newest sessions are checked for unseen runs.
const _recentSessions = 50;

/// What one connected server waits on the user for. Null until the first
/// load finishes (or while the server is not connected), so callers can
/// tell "nothing to do" from "not known yet".
class ServerAttentionNotifier extends Notifier<List<AttentionItem>?> {
  ServerAttentionNotifier(this.serverId);

  final String serverId;
  Timer? _debounce;

  @override
  List<AttentionItem>? build() {
    final link = ref.watch(
      connectionPoolProvider.select((pool) => pool[serverId]),
    );
    final connection = link?.connection;
    if (connection == null) return null;
    final client = connection.client;
    final server = connection.server;

    final stream = ref.watch(serverEventStreamProvider(serverId));
    if (stream != null) {
      final subscriptions = <StreamSubscription<Object?>>[
        stream.events.listen((event) {
          if (event.isExecutionStarted ||
              event.isExecutionTerminal ||
              event.type == 'session.viewed' ||
              waitingRequestAdded(event) != null ||
              waitingRequestSettled(event) != null) {
            _schedule(client, server);
          }
        }),
        stream.statusChanges.listen((_) => _schedule(client, server)),
      ];
      ref.onDispose(() {
        for (final s in subscriptions) {
          s.cancel();
        }
      });
    }
    ref.onDispose(() => _debounce?.cancel());
    unawaited(_load(client, server));
    return null;
  }

  /// Events come in bursts (a run ending sends several); one reload covers
  /// them.
  void _schedule(OpenCodeClient client, ServerConfig server) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_load(client, server)),
    );
  }

  Future<void> _load(OpenCodeClient client, ServerConfig server) async {
    try {
      final items = await loadAttention(client, server);
      if (ref.mounted) state = items;
    } catch (_) {
      // Keep what was there; the next event or reconnect tries again.
    }
  }

  /// Marks [session]'s finished run as seen, here and on the server (which
  /// also clears it in the TUI and tells the phone's other notifications).
  Future<void> markSeen(Session session) async {
    final idle = session.time.idle;
    final client = ref
        .read(connectionPoolProvider)[serverId]
        ?.connection
        ?.client;
    if (idle == null || client == null) return;
    final items = state;
    if (items != null) {
      state = [
        for (final item in items)
          if (!(item.session.id == session.id && item.dismissible)) item,
      ];
    }
    try {
      await client.markSessionViewed(session.id, idle);
    } catch (_) {
      // An older server without the endpoint; the next load brings it back.
    }
  }
}

final serverAttentionProvider =
    NotifierProvider.family<
      ServerAttentionNotifier,
      List<AttentionItem>?,
      String
    >(ServerAttentionNotifier.new);

/// Reads what [client]'s server waits on the user for.
Future<List<AttentionItem>> loadAttention(
  OpenCodeClient client,
  ServerConfig server, {
  DateTime? now,
}) async {
  final (sessions, active) = await (
    client.listRecentSessions(limit: _recentSessions),
    client.activeSessionIds(),
  ).wait;
  final byId = {for (final s in sessions) s.id: s};
  final items = <AttentionItem>[];

  // Only a running session can be asking for something.
  for (final id in active) {
    final session = byId[id] ?? await _session(client, id);
    if (session == null || session.parentID != null) continue;
    final (permissions, forms) = await (
      client
          .listPermissions(id)
          .catchError((Object _) => const <PermissionRequest>[]),
      client
          .listForms(id, directory: session.location.directory)
          .catchError((Object _) => const <FormRequest>[]),
    ).wait;
    if (permissions.isNotEmpty) {
      items.add(
        AttentionItem(
          server: server,
          session: session,
          kind: AttentionKind.permission,
        ),
      );
    } else if (forms.isNotEmpty) {
      items.add(
        AttentionItem(
          server: server,
          session: session,
          kind: AttentionKind.question,
        ),
      );
    }
  }

  final since = (now ?? DateTime.now()).subtract(unseenRunWindow);
  for (final session in sessions) {
    if (active.contains(session.id) || session.isArchived) continue;
    if (!session.hasUnseenRun) continue;
    final kind = switch (session.outcome) {
      'failed' => AttentionKind.failed,
      'succeeded' => AttentionKind.completed,
      // Stopped by the user, or a server that does not say.
      _ => null,
    };
    if (kind == null) continue;
    final item = AttentionItem(server: server, session: session, kind: kind);
    if (item.at.isBefore(since)) continue;
    items.add(item);
  }
  return items;
}

Future<Session?> _session(OpenCodeClient client, String id) async {
  try {
    return await client.getSession(id);
  } catch (_) {
    return null;
  }
}

/// Everything every connected server waits on the user for: questions and
/// permissions first, then finished runs, newest first within each.
final attentionProvider = Provider<List<AttentionItem>>((ref) {
  final ids = ref.watch(
    connectionPoolProvider.select((pool) => pool.keys.toList()),
  );
  final items = [
    for (final id in ids) ...?ref.watch(serverAttentionProvider(id)),
  ];
  items.sort((a, b) {
    final waitsA = a.dismissible ? 1 : 0;
    final waitsB = b.dismissible ? 1 : 0;
    if (waitsA != waitsB) return waitsA - waitsB;
    return b.at.compareTo(a.at);
  });
  return items;
});

/// Whether any connected server has reported yet; until then a count of
/// zero means "not known", not "nothing to do".
final attentionKnownProvider = Provider<bool>((ref) {
  final ids = ref.watch(
    connectionPoolProvider.select((pool) => pool.keys.toList()),
  );
  return ids.any((id) => ref.watch(serverAttentionProvider(id)) != null);
});

/// Sessions whose chat is open (as a page or a pane).
class OpenChatsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  // Calls arrive a microtask late, possibly after the app has gone.
  void opened(String sessionId) {
    if (ref.mounted) state = {...state, sessionId};
  }

  void closed(String sessionId) {
    if (ref.mounted) state = {...state}..remove(sessionId);
  }
}

final openChatsProvider = NotifierProvider<OpenChatsNotifier, Set<String>>(
  OpenChatsNotifier.new,
);

/// Kept alive by an open chat: the session on screen has been seen, so its
/// notifications go, and a run that ends while the user watches never
/// lands in the list. Nothing is marked while the app is in the
/// background, where the chat stays mounted but nobody looks at it.
final sessionSeenProvider = Provider.autoDispose.family<void, String>((
  ref,
  sessionId,
) {
  final serverId = ref.watch(connectionProvider.select((c) => c?.server.id));
  if (serverId == null) return;

  void check() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    final items = ref.read(serverAttentionProvider(serverId));
    final item = items
        ?.where((i) => i.session.id == sessionId && i.dismissible)
        .firstOrNull;
    if (item == null) return;
    unawaited(
      ref
          .read(serverAttentionProvider(serverId).notifier)
          .markSeen(item.session),
    );
    unawaited(
      ref
          .read(pushMessagingProvider)
          ?.clearSession(sessionId)
          .catchError((Object _) {}),
    );
  }

  final chats = ref.read(openChatsProvider.notifier);
  // Deferred: providers may not change others while they build.
  scheduleMicrotask(() => chats.opened(sessionId));
  ref.onDispose(() => scheduleMicrotask(() => chats.closed(sessionId)));
  ref.listen(serverAttentionProvider(serverId), (_, _) => check());
  final lifecycle = AppLifecycleListener(onResume: check);
  ref.onDispose(lifecycle.dispose);
  unawaited(
    ref
        .read(pushMessagingProvider)
        ?.clearSession(sessionId)
        .catchError((Object _) {}),
  );
  check();
});
