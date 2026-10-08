import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout.dart';
import '../../core/models/session.dart';
import '../../core/models/timeline.dart';
import '../../l10n/l10n.dart';
import '../attention/attention_providers.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import '../settings/haptics.dart';
import 'agent_labels.dart';
import 'chat_providers.dart';
import 'composer.dart';
import 'composer_providers.dart';
import 'context_sheet.dart';
import 'expand_downward.dart';
import 'prompt_widgets.dart';
import 'pull_up_to_refresh.dart';
import 'revert_providers.dart';
import 'scroll_to_newest.dart';
import 'session_actions.dart';
import 'status_bar_scroll.dart';
import 'timeline_widgets.dart';
import '../voice/conversation.dart';
import '../voice/speakable.dart';
import '../voice/speech.dart';

/// A session's transcript, updated live, with the input at the bottom.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.session, this.pane = false});

  final Session session;

  /// Shown as the right of two panes rather than as its own page, so it
  /// has no back button.
  final bool pane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = timelineProvider(session.id);
    final timeline = ref.watch(provider);
    final busy = ref.watch(
      activeSessionsProvider.select((ids) => ids.contains(session.id)),
    );
    ref.watch(sessionHapticsProvider(session.id));
    ref.watch(sessionSeenProvider(session.id));
    final rewoundTo = ref.watch(revertProvider(session));
    final conversing = ref.watch(conversationActiveProvider(session.id));

    return StatusBarScrollsToOldest(
      onArrived: () => ref.read(provider.notifier).loadMore(),
      builder: (context, scrollController) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !pane,
          // Without a back button the title would touch the pane divider.
          titleSpacing: pane ? 16 : null,
          title: _ChatTitle(session: session, busy: busy),
          bottom: const LiveStatusBanner(),
          actions: [ContextUsageButton(session: session)],
        ),
        body: PrimaryScrollController.none(
          child: Column(
            children: [
              ReadableWidth(child: TodoStrip(sessionId: session.id)),
              Expanded(
                child: timeline.when(
                  data: (paged) {
                    final entries = _beforeRewind(paged.items, rewoundTo);
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
                                          onLongPress: () {
                                            Feedback.forLongPress(context);
                                            ref
                                                .read(hapticsProvider)
                                                .play(HapticCue.longPress);
                                            _userMessageMenu(
                                              context,
                                              ref,
                                              entry,
                                            );
                                          },
                                          child: TimelineEntryView(
                                            entry: entry,
                                          ),
                                        )
                                      : entry is AssistantEntry &&
                                            assistantText(entry).isNotEmpty
                                      ? GestureDetector(
                                          onLongPress: () {
                                            Feedback.forLongPress(context);
                                            ref
                                                .read(hapticsProvider)
                                                .play(HapticCue.longPress);
                                            _assistantMessageMenu(
                                              context,
                                              ref,
                                              entry,
                                            );
                                          },
                                          child: TimelineEntryView(
                                            entry: entry,
                                          ),
                                        )
                                      : TimelineEntryView(entry: entry);
                                }
                                return ReadableWidth(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: child,
                                  ),
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
              if (rewoundTo != null)
                ReadableWidth(
                  key: const ValueKey('rewind-slot'),
                  child: RewindBanner(session: session),
                ),
              // Keyed so the banner coming and going keeps their state.
              ReadableWidth(
                key: const ValueKey('prompts-slot'),
                child: SessionPromptsPanel(session: session),
              ),
              if (conversing)
                ReadableWidth(
                  key: const ValueKey('conversation-slot'),
                  child: ConversationPanel(session: session),
                ),
              // Kept while conversing so a draft survives.
              ReadableWidth(
                key: const ValueKey('composer-slot'),
                child: Visibility(
                  visible: !conversing,
                  maintainState: true,
                  child: Composer(session: session),
                ),
              ),
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
              key: const Key('rewind-here'),
              leading: const Icon(Icons.undo),
              title: Text(context.l10n.rewindHere),
              subtitle: Text(context.l10n.rewindHereHelp),
              onTap: () => Navigator.pop(context, _MessageAction.rewind),
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
      case _MessageAction.rewind:
        final messenger = ScaffoldMessenger.of(context);
        final l10n = context.l10n;
        try {
          await ref.read(revertProvider(session).notifier).stage(entry.id);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.rewindFailed(e))));
          return;
        }
        // Like undo in an editor: the rewound prompt comes back to edit.
        if (entry.text.isNotEmpty) {
          ref
              .read(composerDraftProvider(session.id).notifier)
              .offer(entry.text);
        }
      case _MessageAction.fork:
        await forkSession(context, ref, session, beforeMessageId: entry.id);
      case _MessageAction.readAloud:
        break;
    }
  }

  Future<void> _assistantMessageMenu(
    BuildContext context,
    WidgetRef ref,
    AssistantEntry entry,
  ) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('copy-reply'),
              leading: const Icon(Icons.copy),
              title: Text(context.l10n.copy),
              onTap: () => Navigator.pop(context, _MessageAction.copy),
            ),
            ListTile(
              key: const Key('read-aloud'),
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(context.l10n.readAloud),
              onTap: () => Navigator.pop(context, _MessageAction.readAloud),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final text = assistantText(entry);
    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: text));
        messenger.showSnackBar(SnackBar(content: Text(l10n.copied)));
      case _MessageAction.readAloud:
        final output = ref.read(speechOutputProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.readingAloud),
            duration: const Duration(minutes: 10),
            action: SnackBarAction(
              label: l10n.stopReading,
              onPressed: output.stop,
            ),
          ),
        );
        await output.speak(
          speakableText(
            text,
            codeSkipped: l10n.speechCodeSkipped,
            truncated: l10n.speechTruncated,
          ),
          localeTag: speechLocaleTag(
            Localizations.localeOf(context).languageCode,
          ),
        );
        messenger.hideCurrentSnackBar();
      case _MessageAction.rewind || _MessageAction.fork:
        break;
    }
  }

  /// The entries before the rewind boundary, or all of them when the
  /// session is not rewound (or the boundary is not loaded).
  static List<TimelineEntry> _beforeRewind(
    List<TimelineEntry> entries,
    String? boundary,
  ) {
    if (boundary == null) return entries;
    final index = entries.indexWhere((e) => e.id == boundary);
    return index < 0 ? entries : entries.sublist(0, index);
  }
}

enum _MessageAction { copy, rewind, fork, readAloud }

/// Shown above the input while the session is rewound, with a way to bring
/// the set-aside messages and file changes back.
class RewindBanner extends ConsumerStatefulWidget {
  const RewindBanner({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<RewindBanner> createState() => _RewindBannerState();
}

class _RewindBannerState extends ConsumerState<RewindBanner> {
  bool _busy = false;

  Future<void> _undo() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(revertProvider(widget.session).notifier).undo();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.rewindFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('rewind-banner'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.undo, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.rewoundNotice,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            key: const Key('rewind-undo'),
            onPressed: _busy ? null : _undo,
            child: Text(context.l10n.rewindUndo),
          ),
        ],
      ),
    );
  }
}

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
