import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import 'chat_providers.dart';
import 'composer.dart';
import 'composer_providers.dart';
import 'prompt_widgets.dart';
import 'timeline_widgets.dart';

/// A session's transcript, updated live, with the input at the bottom.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = timelineProvider(session.id);
    final timeline = ref.watch(provider);
    final busy = ref.watch(
      activeSessionsProvider.select((ids) => ids.contains(session.id)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: const LiveStatusBanner(),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: SessionBusyIndicator(size: 18)),
            ),
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      body: Column(
        children: [
          TodoStrip(sessionId: session.id),
          Expanded(
            child: timeline.when(
              data: (paged) {
                final entries = paged.items;
                final shownIds = {for (final e in entries) e.id};
                final pending = ref
                    .watch(pendingPromptsProvider(session.id))
                    .where((p) => !shownIds.contains(p.id))
                    .toList();
                if (entries.isEmpty && pending.isEmpty) {
                  return const Center(child: Text('メッセージはまだありません'));
                }
                // Reversed so the list starts at the newest item. Pending
                // prompts sit below the transcript; the extra last index is
                // the "older history" control at the top.
                final count = pending.length + entries.length;
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
                    itemCount: count + 1,
                    itemBuilder: (context, index) {
                      if (index == count) {
                        return OlderHistoryIndicator(
                          paged: paged,
                          onRetry: () => ref.read(provider.notifier).loadMore(),
                        );
                      }
                      final Widget child;
                      if (index < pending.length) {
                        final prompt = pending[pending.length - 1 - index];
                        child = PendingPromptBubble(
                          prompt: prompt,
                          onDismiss: () => ref
                              .read(pendingPromptsProvider(session.id).notifier)
                              .dismiss(prompt.id),
                        );
                      } else {
                        final i = index - pending.length;
                        child = TimelineEntryView(
                          entry: entries[entries.length - 1 - i],
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: child,
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
          ),
          SessionPromptsPanel(session: session),
          Composer(session: session),
        ],
      ),
    );
  }
}
