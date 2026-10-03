import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/models/timeline.dart';
import '../../l10n/l10n.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import 'agent_labels.dart';
import 'chat_providers.dart';
import 'composer.dart';
import 'composer_providers.dart';
import 'context_sheet.dart';
import 'expand_downward.dart';
import 'prompt_widgets.dart';
import 'pull_up_to_refresh.dart';
import 'scroll_to_newest.dart';
import 'session_actions.dart';
import 'status_bar_scroll.dart';
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

    return StatusBarScrollsToOldest(
      onArrived: () => ref.read(provider.notifier).loadMore(),
      builder: (context, scrollController) => Scaffold(
        appBar: AppBar(
          title: _ChatTitle(session: session, busy: busy),
          bottom: const LiveStatusBanner(),
          actions: [ContextUsageButton(session: session)],
        ),
        body: PrimaryScrollController.none(
          child: Column(
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
                      return Center(child: Text(context.l10n.messagesEmpty));
                    }
                    // Reversed so the list starts at the newest item. Pending
                    // prompts sit below the transcript; the extra last index is
                    // the "older history" control at the top. Pulling past the
                    // newest item refetches the latest page.
                    final count = pending.length + entries.length;
                    return Stack(
                      children: [
                        PullUpToRefresh(
                          onRefresh: () => ref.read(provider.notifier).resync(),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.extentAfter < 600 &&
                                  !scrollController.scrollingToOldest) {
                                ref.read(provider.notifier).loadMore();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: scrollController,
                              reverse: true,
                              // Lets accordions open downward from their header.
                              physics: AnchoredScrollPhysics(
                                anchor: ScrollAnchor(),
                                // Short transcripts can still be pulled to refresh.
                                parent: const AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: count + 1,
                              itemBuilder: (context, index) {
                                if (index == count) {
                                  return OlderHistoryIndicator(
                                    paged: paged,
                                    onRetry: () =>
                                        ref.read(provider.notifier).loadMore(),
                                  );
                                }
                                final Widget child;
                                if (index < pending.length) {
                                  final prompt =
                                      pending[pending.length - 1 - index];
                                  child = PendingPromptBubble(
                                    prompt: prompt,
                                    onDismiss: () => ref
                                        .read(
                                          pendingPromptsProvider(session.id)
                                              .notifier,
                                        )
                                        .dismiss(prompt.id),
                                  );
                                } else {
                                  final i = index - pending.length;
                                  final entry = entries[entries.length - 1 - i];
                                  child = entry is UserEntry
                                      ? GestureDetector(
                                          onLongPress: () => _userMessageMenu(
                                            context,
                                            ref,
                                            entry,
                                          ),
                                          child: TimelineEntryView(
                                            entry: entry,
                                          ),
                                        )
                                      : TimelineEntryView(entry: entry);
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
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: ScrollToNewestButton(
                            controller: scrollController,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.l10n.messagesLoadFailed(e)),
                    ),
                  ),
                ),
              ),
              SessionPromptsPanel(session: session),
              Composer(session: session),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _userMessageMenu(
    BuildContext context,
    WidgetRef ref,
    UserEntry entry,
  ) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.text.isNotEmpty)
              ListTile(
                key: const Key('copy-message'),
                leading: const Icon(Icons.copy),
                title: Text(context.l10n.copy),
                onTap: () => Navigator.pop(context, _MessageAction.copy),
              ),
            ListTile(
              key: const Key('fork-here'),
              leading: const Icon(Icons.fork_right),
              title: Text(context.l10n.forkFromHere),
              subtitle: Text(context.l10n.forkFromHereHelp),
              onTap: () => Navigator.pop(context, _MessageAction.fork),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _MessageAction.copy:
        final messenger = ScaffoldMessenger.of(context);
        final copied = context.l10n.copied;
        await Clipboard.setData(ClipboardData(text: entry.text));
        messenger.showSnackBar(SnackBar(content: Text(copied)));
      case _MessageAction.fork:
        await forkSession(context, ref, session, beforeMessageId: entry.id);
    }
  }
}

enum _MessageAction { copy, fork }

/// Session title over a monospace line with the agent and model, led by a
/// pulsing dot while the session is running.
class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({required this.session, required this.busy});

  final Session session;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(sessionSettingsProvider(session));
    final detail = [
      if (settings.agent case final agent?) agentDisplayName(agent),
      ?settings.model?.label,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          session.displayTitle ?? context.l10n.untitledSession,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (busy || detail.isNotEmpty)
          Row(
            children: [
              if (busy) ...[const LiveDot(size: 6), const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  busy && detail.isEmpty ? context.l10n.running : detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
