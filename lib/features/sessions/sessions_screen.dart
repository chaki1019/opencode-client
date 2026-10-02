import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../core/paging.dart';
import '../../core/api/api_errors.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import '../worktrees/worktrees_screen.dart';
import 'session_providers.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionListProvider(project);
    final sessions = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.displayName),
        bottom: const LiveStatusBanner(),
        actions: [
          if (project.id != 'global')
            IconButton(
              key: const Key('worktrees'),
              tooltip: 'worktree',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorktreesScreen(project: project),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-session'),
        // Tabs share one route, so the default tag would clash.
        heroTag: null,
        onPressed: () => _createSession(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新しいセッション'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: sessions.when(
          data: (paged) => paged.items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [Center(child: Text('セッションはまだありません'))],
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 400) {
                      ref.read(provider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: paged.items.length + 1,
                    itemBuilder: (context, index) => index < paged.items.length
                        ? _SessionTile(session: paged.items[index])
                        : _PagingFooter(
                            paged: paged,
                            onRetry: () =>
                                ref.read(provider.notifier).loadMore(),
                          ),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('セッションを読み込めませんでした: $e')],
          ),
        ),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final session = await client.createSession(directory: project.directory);
      router.push(
        '/sessions/${Uri.encodeComponent(session.id)}',
        extra: session,
      );
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('セッションを作成できませんでした: $e')));
    }
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      activeSessionsProvider.select((ids) => ids.contains(session.id)),
    );
    final details = [
      relativeTime(session.updatedAt),
      if (session.model != null) session.model!.label,
    ].join(' · ');
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 20,
        child: Center(
          child: busy
              ? const SessionBusyIndicator()
              : Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
      minLeadingWidth: 20,
      title: Text(
        session.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(details, style: theme.textTheme.labelSmall),
      onTap: () => context.push(
        '/sessions/${Uri.encodeComponent(session.id)}',
        extra: session,
      ),
    );
  }
}

/// Spinner while loading the next page, or a retry button if it failed.
class _PagingFooter extends StatelessWidget {
  const _PagingFooter({required this.paged, required this.onRetry});

  final PagedItems<Object?> paged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (paged.loadMoreError != null) {
      return Center(
        child: TextButton(onPressed: onRetry, child: const Text('再読み込み')),
      );
    }
    if (!paged.hasMore) return const SizedBox(height: 24);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
