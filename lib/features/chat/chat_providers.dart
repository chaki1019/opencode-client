import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/events/server_event.dart';
import '../../core/models/timeline.dart';
import '../../core/paging.dart';
import '../../core/sync/live_timeline.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';

/// A session's timeline, oldest first, kept live by server events.
/// [loadMore] prepends older history.
class TimelineNotifier extends PagedNotifier<TimelineEntry> {
  TimelineNotifier(this.sessionId);

  final String sessionId;

  /// Events that arrive while a page is loading are replayed onto it, so a
  /// reply that streams during the initial fetch is not lost.
  List<ServerEvent>? _buffer;
  late LiveTimeline _live;
  bool _resyncing = false;

  @override
  Future<PagedItems<TimelineEntry>> build() async {
    _live = LiveTimeline(sessionId);
    _buffer = [];
    listenToServerEvents(ref, onEvent: _onEvent, onResync: resync);
    try {
      final first = await super.build();
      return PagedItems(
        items: _replay(first.items),
        nextCursor: first.nextCursor,
      );
    } finally {
      _buffer = null;
    }
  }

  @override
  Future<Page<TimelineEntry>> fetch(String? cursor) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return const Page([], null);
    return client.listMessages(sessionId: sessionId, cursor: cursor);
  }

  @override
  List<TimelineEntry> merge(
    List<TimelineEntry> current,
    List<TimelineEntry> page,
  ) => [...page.where((e) => !current.any((c) => c.id == e.id)), ...current];

  void _onEvent(ServerEvent event) {
    if (event.sessionId != sessionId) return;
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(event);
      return;
    }
    final current = state.value;
    if (current == null) return;
    switch (_live.apply(current.items, event)) {
      case Changed(:final entries):
        state = AsyncData(current.copyWith(items: entries));
      case NeedsResync():
        unawaited(resync());
      case Unchanged():
        break;
    }
  }

  List<TimelineEntry> _replay(List<TimelineEntry> items) {
    var result = items;
    var needsResync = false;
    for (final event in _buffer ?? const <ServerEvent>[]) {
      switch (_live.apply(result, event)) {
        case Changed(:final entries):
          result = entries;
        case NeedsResync():
          needsResync = true;
        case Unchanged():
          break;
      }
    }
    if (needsResync) Future.microtask(resync);
    return result;
  }

  /// Refetches the newest page and splices it onto the loaded history.
  Future<void> resync() async {
    if (_resyncing || !ref.mounted || state.value == null) return;
    _resyncing = true;
    _buffer = [];
    try {
      final latest = await fetch(null);
      if (!ref.mounted) return;
      final current = state.value!;
      final items = _replay(latest.items);
      final overlap = items.isEmpty
          ? -1
          : current.items.indexWhere((e) => e.id == items.first.id);
      state = AsyncData(
        overlap < 0
            // No overlap: the gap is unknown, so restart from the newest page.
            ? current.copyWith(
                items: items,
                nextCursor: () => latest.nextCursor,
              )
            : current.copyWith(
                items: [...current.items.sublist(0, overlap), ...items],
              ),
      );
    } catch (_) {
      // Keep what is shown; the next event or reconnect retries.
    } finally {
      _buffer = null;
      _resyncing = false;
    }
  }
}

final timelineProvider = AsyncNotifierProvider.autoDispose
    .family<TimelineNotifier, PagedItems<TimelineEntry>, String>(
      TimelineNotifier.new,
    );
