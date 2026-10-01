import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import 'chat_providers.dart';
import 'timeline_widgets.dart';

/// Read-only transcript of a session. Sending and live updates arrive in
/// later phases.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = timelineProvider(session.id);
    final timeline = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      body: timeline.when(
        data: (paged) {
          final entries = paged.items;
          if (entries.isEmpty) {
            return const Center(child: Text('メッセージはまだありません'));
          }
          // Reversed so the list starts at the newest entry; the extra last
          // index is the "older history" control at the top.
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 600) {
                ref.read(provider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == entries.length) {
                  return OlderHistoryIndicator(
                    paged: paged,
                    onRetry: () => ref.read(provider.notifier).loadMore(),
                  );
                }
                final entry = entries[entries.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: TimelineEntryView(entry: entry),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('メッセージを読み込めませんでした: $e'),
          ),
        ),
      ),
    );
  }
}
