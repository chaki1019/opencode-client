import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/events/server_event.dart';
import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../core/paging.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';

class SessionListNotifier extends PagedNotifier<Session> {
  SessionListNotifier(this.project);

  final Project project;

  @override
  Future<PagedItems<Session>> build() {
    ref.watch(connectionProvider);
    listenToServerEvents(
      ref,
      onEvent: _onEvent,
      onResync: () => ref.invalidateSelf(),
    );
    return super.build();
  }

  @override
  Future<Page<Session>> fetch(String? cursor) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return const Page([], null);
    final page = await client.listSessions(
      directory: project.directory,
      cursor: cursor,
    );
    return Page(
      page.items.where((s) => !s.isArchived).toList(),
      page.nextCursor,
    );
  }

  /// Older sessions are appended below.
  @override
  List<Session> merge(List<Session> current, List<Session> page) => [
    ...current,
    ...page.where((s) => !current.any((c) => c.id == s.id)),
  ];

  /// Shows [session] in place of its old copy, without waiting for the event.
  void replace(Session session) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final s in current.items) s.id == session.id ? session : s,
        ],
      ),
    );
  }

  /// Drops [sessionId] from the list, without waiting for the event.
  void remove(String sessionId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((s) => s.id != sessionId).toList(),
      ),
    );
  }

  void _onEvent(ServerEvent event) {
    final current = state.value;
    final id = event.sessionId;
    if (current == null || id == null) return;
    final items = current.items;
    final index = items.indexWhere((s) => s.id == id);
    final now =
        event.created ?? DateTime.now().millisecondsSinceEpoch.toDouble();
    List<Session>? updated;

    switch (event.type) {
      case 'session.created':
        final data = event.data;
        final location = data['location'];
        final directory = location is Map
            ? location['directory'] as String?
            : event.directory;
        if (index >= 0 ||
            directory != project.directory ||
            data['parentID'] != null) {
          return;
        }
        updated = [
          Session(
            id: id,
            projectID: data['projectID'] as String? ?? project.id,
            title: data['title'] as String?,
            location: SessionLocation(
              directory: directory!,
              workspaceID: location is Map
                  ? location['workspaceID'] as String?
                  : null,
            ),
            time: SessionTime(created: now, updated: now),
          ),
          ...items,
        ];
      case 'session.renamed' || 'session.updated':
        final title = event.data['title'];
        if (index < 0 || title is! String) return;
        updated = [...items]..[index] = items[index].copyWith(title: title);
      case 'session.deleted':
        if (index < 0) return;
        updated = [...items]..removeAt(index);
      case 'session.execution.started':
        // Activity moves a session to the top, like a fresh update.
        if (index < 0) return;
        final session = items[index];
        updated = [
          session.copyWith(time: session.time.copyWith(updated: now)),
          ...items.where((s) => s.id != id),
        ];
    }
    if (updated != null) state = AsyncData(current.copyWith(items: updated));
  }
}

final sessionListProvider = AsyncNotifierProvider.autoDispose
    .family<SessionListNotifier, PagedItems<Session>, Project>(
      SessionListNotifier.new,
    );
