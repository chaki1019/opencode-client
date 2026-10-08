import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../home/pane_selection.dart';
import '../push/push_providers.dart';
import 'attention_providers.dart';

/// Every session that waits on the user across the connected servers: the
/// list behind the app badge.
class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = ref.watch(attentionProvider);
    final known = ref.watch(attentionKnownProvider);
    final servers = ref.watch(
      connectionPoolProvider.select((pool) => pool.length),
    );
    final theme = Theme.of(context);
    final note = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Text(
        l10n.attentionScope,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.attentionTitle)),
      body: !known && servers > 0
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                  child: Text(
                    l10n.attentionEmpty,
                    key: const Key('attention-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                note,
              ],
            )
          : ListView(
              children: [
                for (final item in items)
                  _AttentionTile(item: item, showServer: servers > 1),
                note,
              ],
            ),
    );
  }
}

class _AttentionTile extends ConsumerWidget {
  const _AttentionTile({required this.item, required this.showServer});

  final AttentionItem item;
  final bool showServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final (icon, color, label) = switch (item.kind) {
      AttentionKind.permission => (
        Icons.front_hand_outlined,
        scheme.tertiary,
        l10n.pushHeadlinePermission,
      ),
      AttentionKind.question => (
        Icons.help_outline,
        scheme.tertiary,
        l10n.pushHeadlineQuestion,
      ),
      AttentionKind.failed => (
        Icons.error_outline,
        scheme.error,
        l10n.pushHeadlineFailed,
      ),
      AttentionKind.completed => (
        Icons.check_circle_outline,
        colors.success,
        l10n.pushHeadlineCompleted,
      ),
    };
    final folder = item.session.location.directory
        .split(RegExp(r'[\\/]'))
        .lastWhere((part) => part.isNotEmpty, orElse: () => '');
    final details = [
      label,
      if (folder.isNotEmpty) folder,
      if (showServer) item.server.displayName,
      relativeTime(l10n, item.at),
    ].join(' · ');
    final tile = ListTile(
      key: Key('attention-${item.server.id}-${item.session.id}'),
      leading: Icon(icon, color: color),
      title: Text(
        item.session.displayTitle ?? l10n.untitledSession,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => openAttentionItem(ref, item),
    );
    if (!item.dismissible) return tile;
    return Dismissible(
      key: ValueKey('${item.server.id}/${item.session.id}'),
      background: _SeenBackground(alignment: Alignment.centerLeft),
      secondaryBackground: _SeenBackground(alignment: Alignment.centerRight),
      onDismissed: (_) => ref
          .read(serverAttentionProvider(item.server.id).notifier)
          .markSeen(item.session),
      child: tile,
    );
  }
}

class _SeenBackground extends StatelessWidget {
  const _SeenBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Text(
            context.l10n.attentionMarkSeen,
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Switches to the item's server when needed and opens its session.
Future<void> openAttentionItem(WidgetRef ref, AttentionItem item) async {
  final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
  try {
    if (ref.read(connectionProvider)?.server.id != item.server.id) {
      await ref.read(connectionProvider.notifier).connectSaved(item.server);
    }
    final router = ref.read(routerProvider);
    router.go('/projects');
    openSession(router, ref.read(paneSelectionProvider.notifier), item.session);
  } on Object catch (e) {
    final context = messenger?.context;
    if (messenger == null || context == null || !context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.pushOpenFailed('$e'))),
    );
  }
}
