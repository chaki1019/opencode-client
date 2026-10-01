import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../core/paging.dart';
import '../connection/connection_providers.dart';

class SessionListNotifier extends PagedNotifier<Session> {
  SessionListNotifier(this.project);

  final Project project;

  @override
  Future<Page<Session>> fetch(String? cursor) async {
    final client = ref.watch(connectionProvider)?.client;
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
}

final sessionListProvider = AsyncNotifierProvider.autoDispose
    .family<SessionListNotifier, PagedItems<Session>, Project>(
      SessionListNotifier.new,
    );
