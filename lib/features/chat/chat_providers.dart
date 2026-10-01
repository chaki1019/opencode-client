import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/timeline.dart';
import '../../core/paging.dart';
import '../connection/connection_providers.dart';

/// A session's timeline, oldest first. [loadMore] prepends older history.
class TimelineNotifier extends PagedNotifier<TimelineEntry> {
  TimelineNotifier(this.sessionId);

  final String sessionId;

  @override
  Future<Page<TimelineEntry>> fetch(String? cursor) async {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const Page([], null);
    return client.listMessages(sessionId: sessionId, cursor: cursor);
  }

  @override
  List<TimelineEntry> merge(
    List<TimelineEntry> current,
    List<TimelineEntry> page,
  ) => [...page.where((e) => !current.any((c) => c.id == e.id)), ...current];
}

final timelineProvider = AsyncNotifierProvider.autoDispose
    .family<TimelineNotifier, PagedItems<TimelineEntry>, String>(
      TimelineNotifier.new,
    );
