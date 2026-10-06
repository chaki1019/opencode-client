import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/events/event_stream.dart';
import '../../core/models/server_config.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import '../live/live_widgets.dart';
import '../live/server_activity.dart';

/// The project list's side menu: the servers the user connected to on top,
/// app settings at the bottom. Every connected server stays in the list,
/// even after it drops; the drawer shows what the ones in the background
/// are doing. The one on screen is the highlighted row.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// The server being connected to, while it is.
  String? _switching;

  Future<void> _switchTo(ServerConfig server) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    setState(() => _switching = server.id);
    try {
      await ref.read(connectionProvider.notifier).connectSaved(server);
      if (mounted) navigator.pop();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.serverSwitchFailed(server.displayName, l10n.connectError(e)),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  /// Closes the drawer first so coming back shows the list, not the menu.
  void _open(String location) {
    Navigator.of(context).pop();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = ref.watch(connectionProvider)?.server;
    final servers = ref.watch(connectedServersProvider);
    final pool = ref.watch(connectionPoolProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.servers,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final server in servers)
                    _ServerTile(
                      server: server,
                      isCurrent: server.id == current?.id,
                      isSwitching: server.id == _switching,
                      link: pool[server.id],
                      onTap: server.id == current?.id
                          ? () => Navigator.of(context).pop()
                          : _switching != null
                          ? () {}
                          : () => _switchTo(server),
                    ),
                  ListTile(
                    key: const Key('add-server'),
                    leading: const Icon(Icons.add),
                    title: Text(l10n.addServer),
                    onTap: () => _open('/add-server'),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              key: const Key('push-settings'),
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.pushTitle),
              onTap: () => _open('/push'),
            ),
            ListTile(
              key: const Key('app-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settingsTitle),
              onTap: () => _open('/settings'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile({
    required this.server,
    required this.isCurrent,
    required this.isSwitching,
    required this.link,
    required this.onTap,
  });

  final ServerConfig server;
  final bool isCurrent;
  final bool isSwitching;
  final ServerLink? link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final activity = ref.watch(serverActivityProvider(server.id));
    final stream = ref.watch(serverStreamStatusProvider(server.id));
    final link = this.link;
    // A connection that failed, or one whose live updates dropped.
    final failed =
        link?.error != null ||
        stream == EventStreamStatus.reconnecting ||
        stream == EventStreamStatus.stopped;
    // What the server is up to while it is not on screen.
    final status = link == null
        ? null
        : failed
        ? l10n.serverUnreachable
        : [
            if (!isCurrent && activity.running.isNotEmpty)
              l10n.serverRunning(activity.running.length),
            if (!isCurrent && activity.finished > 0)
              l10n.serverFinished(activity.finished),
          ].join(' · ');
    final Widget? indicator = isSwitching || link?.isConnecting == true
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : failed
        ? Icon(Icons.cloud_off_outlined, size: 18, color: scheme.error)
        : isCurrent
        ? LiveDot(size: 8, color: colors.success, pulse: false)
        : activity.finished > 0
        ? Badge(
            key: Key('drawer-server-finished-${server.id}'),
            label: Text('${activity.finished}'),
          )
        : activity.running.isNotEmpty
        ? LiveDot(size: 8, color: colors.running, pulse: false)
        : link?.connection != null
        ? LiveDot(size: 8, color: colors.success, pulse: false)
        : null;
    return ListTile(
      key: Key('drawer-server-${server.id}'),
      selected: isCurrent,
      leading: const Icon(Icons.dns_outlined),
      title: Text(
        server.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        status == null || status.isEmpty ? server.baseUrl : status,
        key: Key('drawer-server-status-${server.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: status == null || status.isEmpty ? AppFonts.mono : null,
          color: failed ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
      trailing: indicator,
      onTap: onTap,
    );
  }
}
