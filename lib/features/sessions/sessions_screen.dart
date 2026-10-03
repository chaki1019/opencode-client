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
import '../ads/ad_widgets.dart';
import '../chat/session_actions.dart';
import '../connection/connection_providers.dart';
import '../home/pane_selection.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import '../projects/project_tools.dart';
import '../settings/haptics.dart';
import 'session_providers.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key, required this.project, this.pane = false});

  final Project project;

  /// Shown as the left of two panes rather than as its own page: back
  /// returns the pane to the project list, and the open session is marked.
  final bool pane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionListProvider(project);
    final sessions = ref.watch(provider);
    final panes = ref.read(paneSelectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: pane ? BackButton(onPressed: panes.showProjects) : null,
        title: Text(project.displayName),
        bottom: const LiveStatusBanner(),
        actions: [ProjectToolsButton(project: project)],
      ),
      bottomNavigationBar: const AdBanner(),
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
                        ? _SessionTile(
                            project: project,
                            session: paged.items[index],
                            pane: pane,
                          )
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
    final panes = ref.read(paneSelectionProvider.notifier);
    try {
      final session = await client.createSession(directory: project.directory);
      openSession(router, panes, session);
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sessionCreateFailed(e))),
      );
    }
  }
}

/// A session row. Swipe right to rename, left to delete; long-press offers
/// both.
class _SessionTile extends ConsumerWidget {
  const _SessionTile({
    required this.project,
    required this.session,
    required this.pane,
  });

  final Project project;
  final Session session;
  final bool pane;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final list = ref.read(sessionListProvider(project).notifier);
    final panes = ref.read(paneSelectionProvider.notifier);
    final updated = await renameSession(context, ref, session);
    if (updated == null) return;
    list.replace(updated);
    panes.updated(updated);
  }

  Future<bool> _delete(BuildContext context, WidgetRef ref) async {
    final panes = ref.read(paneSelectionProvider.notifier);
    final deleted = await deleteSession(context, ref, session);
    if (deleted) panes.removed(session.id);
    return deleted;
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    ref.read(hapticsProvider).play(HapticCue.longPress);
    final action = await showModalBottomSheet<_TileAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('session-rename'),
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.rename),
              onTap: () => Navigator.pop(context, _TileAction.rename),
            ),
            ListTile(
              key: const Key('session-delete'),
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, _TileAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TileAction.rename:
        await _rename(context, ref);
      case _TileAction.delete:
        final list = ref.read(sessionListProvider(project).notifier);
        if (await _delete(context, ref)) list.remove(session.id);
    }
  }

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
    final scheme = theme.colorScheme;
    final open =
        pane &&
        ref.watch(paneSelectionProvider.select((s) => s.session?.id)) ==
            session.id;
    return Dismissible(
      key: ValueKey(session.id),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        icon: Icons.edit,
        label: context.l10n.rename,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        icon: Icons.delete_outline,
        label: context.l10n.delete,
      ),
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          ref.read(hapticsProvider).play(HapticCue.swipeThreshold);
        }
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return _delete(context, ref);
        }
        // Renaming keeps the row; it springs back after the dialog.
        await _rename(context, ref);
        return false;
      },
      onDismissed: (_) =>
          ref.read(sessionListProvider(project).notifier).remove(session.id),
      child: ListTile(
        selected: open,
        selectedTileColor: scheme.primaryContainer,
        selectedColor: scheme.onPrimaryContainer,
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
        onTap: () => openSession(
          GoRouter.of(context),
          ref.read(paneSelectionProvider.notifier),
          session,
        ),
        onLongPress: () => _menu(context, ref),
      ),
    );
  }
}

enum _TileAction { rename, delete }

/// What shows behind a session row while it is swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: foreground)),
          ],
        ),
      ),
    ),
  );
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
