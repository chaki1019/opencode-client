import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/server_config.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_widgets.dart';

/// The project list's side menu: servers to switch between on top, app
/// settings at the bottom. One server is connected at a time.
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
    final saved = ref.watch(savedServersProvider).value ?? const [];
    // A server connected without saving is still listed while it is open.
    final servers = [
      if (current != null && !saved.any((s) => s.id == current.id)) current,
      ...saved,
    ];
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
            if (current != null)
              ListTile(
                key: const Key('diagnostics'),
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text(l10n.diagnosticsTitle),
                onTap: () => _open('/diagnostics'),
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

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.isCurrent,
    required this.isSwitching,
    required this.onTap,
  });

  final ServerConfig server;
  final bool isCurrent;
  final bool isSwitching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        server.baseUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: AppFonts.mono,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: isSwitching
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCurrent
          ? LiveDot(size: 8, color: AppColors.of(context).success, pulse: false)
          : null,
      onTap: onTap,
    );
  }
}
