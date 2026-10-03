import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../core/paging.dart';
import '../../core/api/api_errors.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import '../projects/project_tools.dart';
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
          ProjectToolsButton(project: project),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('new-session'),
        // The terminal list opens over this page with a FAB of its own;
        // without a tag they don't fly between the pages.
        heroTag: null,
        tooltip: context.l10n.newSession,
        onPressed: () => _createSession(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: sessions.when(
          data: (paged) => paged.items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [Center(child: Text(context.l10n.sessionsEmpty))],
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
            children: [Text(context.l10n.sessionsLoadFailed(e))],
          ),
        ),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    try {
      final session = await client.createSession(directory: project.directory);
      router.push(
        '/sessions/${Uri.encodeComponent(session.id)}',
        extra: session,
      );
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sessionCreateFailed(e))),
      );
    }
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(
      sessionActivityProvider((
        sessionId: session.id,
        directory: session.location.directory,
      )),
    );
    final details = [
      relativeTime(context.l10n, session.updatedAt),
      if (session.model != null) session.model!.label,
      if (session.cost case final cost? when cost > 0) formatCost(cost),
    ].join(' · ');
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    return ListTile(
      title: Text(
        session.displayTitle ?? context.l10n.untitledSession,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            if (activity != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SessionActivityLabel(activity: activity, style: style),
              ),
              const TextSpan(text: ' · '),
            ],
            TextSpan(text: details),
          ],
        ),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push(
        '/sessions/${Uri.encodeComponent(session.id)}',
        extra: session,
      ),
    );
  }
}

/// A colored marker and word for what a session is doing.
class SessionActivityLabel extends StatelessWidget {
  const SessionActivityLabel({super.key, required this.activity, this.style});

  final SessionActivity activity;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final (Widget marker, String label, Color color) = switch (activity) {
      SessionActivity.running => (
        const SessionBusyIndicator(size: 12),
        l10n.running,
        AppColors.of(context).running,
      ),
      SessionActivity.waiting => (
        Icon(Icons.pan_tool_outlined, size: 12, color: scheme.tertiary),
        l10n.sessionWaiting,
        scheme.tertiary,
      ),
      SessionActivity.failed => (
        Icon(Icons.error_outline, size: 12, color: scheme.error),
        l10n.sessionFailed,
        scheme.error,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 4),
        Text(
          label,
          style: style?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
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
        child: TextButton(onPressed: onRetry, child: Text(context.l10n.reload)),
      );
    }
    if (!paged.hasMore) return const SizedBox(height: 24);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
