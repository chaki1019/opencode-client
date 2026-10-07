import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/models/server_config.dart';
import '../../core/push/computer_plugin.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import 'push_plugin_update.dart';
import 'push_providers.dart';

/// The `opencode.json` entry that loads the plugin. The plugin makes its
/// own pairing key, which the app reads back, so only a relay other than
/// the public one needs passing.
String pluginConfigSnippet({required String relayUrl}) =>
    _sameUrl(relayUrl, defaultPushRelayUrl)
    ? '"plugins": ["$pushPluginPackage"]'
    : '''
"plugins": [
  {
    "package": "$pushPluginPackage",
    "options": {
      "relay": "$relayUrl"
    }
  }
]''';

bool _sameUrl(String a, String b) =>
    a.replaceAll(RegExp(r'/+$'), '') == b.replaceAll(RegExp(r'/+$'), '');

/// Notification settings, which belong to each server. Opened without
/// [serverId], it lists the servers to pick from, or goes straight to the
/// only one.
class PushSettingsScreen extends ConsumerWidget {
  const PushSettingsScreen({super.key, this.serverId});

  final String? serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(listedServersProvider);
    final config = ref.watch(pushConfigProvider);
    final server = serverId == null
        ? (servers.length == 1 ? servers.single : null)
        : servers.where((s) => s.id == serverId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pushTitle)),
      body: !config.isConfigured
          ? _Message(context.l10n.pushNotConfigured)
          : server != null
          ? _PairingView(server: server, relayUrl: config.relayUrl)
          : serverId == null
          ? _ServerList(servers: servers)
          : const SizedBox.shrink(),
    );
  }
}

/// Every listed server with whether its notifications are on.
class _ServerList extends StatelessWidget {
  const _ServerList({required this.servers});

  final List<ServerConfig> servers;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      readableSide(context),
      0,
      readableSide(context),
      24,
    ),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          context.l10n.pushChooseServer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      for (final server in servers) _ServerTile(server: server),
    ],
  );
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile({required this.server});

  final ServerConfig server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled =
        ref.watch(pushPairingProvider(server.id)).value?.enabled ?? false;
    final plugin = enabled
        ? ref.watch(computerPluginProvider(server.id)).value?.status
        : null;
    final status = !enabled
        ? l10n.pushOff
        : switch (plugin) {
            ComputerPluginStatus.active => l10n.pushOnActive,
            null => l10n.pushOn,
            _ => l10n.pushOnCheck,
          };
    return ListTile(
      key: Key('push-server-${server.id}'),
      leading: Icon(
        enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      title: Text(
        server.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(status, key: Key('push-server-status-${server.id}')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/push/${server.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, key: const Key('push-message')),
  );
}

class _PairingView extends ConsumerStatefulWidget {
  const _PairingView({required this.server, required this.relayUrl});

  final ServerConfig server;
  final String relayUrl;

  @override
  ConsumerState<_PairingView> createState() => _PairingViewState();
}

class _PairingViewState extends ConsumerState<_PairingView> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
      if (done != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
    } on PushSetupException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.error) {
            PushSetupError.notConfigured => l10n.pushNotConfigured,
            PushSetupError.permissionDenied => l10n.pushPermissionDenied,
            PushSetupError.noToken => l10n.pushNoToken,
          }),
        ),
      );
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pushFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = pushPairingProvider(widget.server.id);
    final pairing = ref.watch(provider);
    // Picks up the computer's key before notifications are turned on.
    ref.watch(computerPluginProvider(widget.server.id));
    return pairing.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(context.l10n.pushFailed('$e')),
      data: (pairing) => ListView(
        padding: EdgeInsets.fromLTRB(
          readableSide(context),
          0,
          readableSide(context),
          24,
        ),
        children: [
          SwitchListTile(
            key: const Key('push-switch'),
            title: Text(context.l10n.pushReceive),
            subtitle: Text(widget.server.displayName),
            value: pairing.enabled,
            onChanged: _busy
                ? null
                : (on) => _run(
                    on
                        ? ref.read(provider.notifier).enable
                        : ref.read(provider.notifier).disable,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              context.l10n.pushWhat,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (pairing.enabled) ...[
            _ComputerStatus(serverId: widget.server.id),
            _Setup(relayUrl: widget.relayUrl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                key: const Key('push-test'),
                icon: const Icon(Icons.send_outlined),
                label: Text(context.l10n.pushSendTest),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(provider.notifier)
                            .sendTest(context.l10n.pushTestTitle),
                        done: context.l10n.pushTestSent,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComputerStatus extends ConsumerWidget {
  const _ComputerStatus({required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = computerPluginProvider(serverId);
    final check = ref.watch(provider);
    final (icon, color, text) = switch (check) {
      AsyncData(value: final check?) => switch (check.status) {
        ComputerPluginStatus.active => (
          Icons.check_circle_outline,
          colors.primary,
          l10n.pushComputerActive,
        ),
        ComputerPluginStatus.failed => (
          Icons.error_outline,
          colors.error,
          l10n.pushComputerFailed(check.error ?? ''),
        ),
        ComputerPluginStatus.otherKey => (
          Icons.key_off_outlined,
          colors.error,
          l10n.pushComputerOtherKey,
        ),
        ComputerPluginStatus.notLoaded => (
          Icons.restart_alt,
          colors.tertiary,
          l10n.pushComputerNotLoaded,
        ),
        ComputerPluginStatus.missing => (
          Icons.radio_button_unchecked,
          colors.onSurfaceVariant,
          l10n.pushComputerMissing,
        ),
      },
      AsyncLoading() => (null, null, null),
      _ => (
        Icons.help_outline,
        colors.onSurfaceVariant,
        l10n.pushComputerUnknown,
      ),
    };
    final tile = ListTile(
      key: const Key('push-computer'),
      leading: icon == null
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      // The version beside the name, as on the diagnostics page.
      title: switch (check.value?.version) {
        final version? => Text.rich(
          TextSpan(
            text: l10n.pushComputerTitle,
            children: [
              TextSpan(
                text: ' ($version)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        null => Text(l10n.pushComputerTitle),
      },
      subtitle: text == null ? null : Text(text),
      trailing: IconButton(
        key: const Key('push-computer-refresh'),
        tooltip: l10n.pushComputerRefresh,
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(provider),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        PushPluginUpdate(serverId: serverId),
      ],
    );
  }
}

class _Setup extends StatelessWidget {
  const _Setup({required this.relayUrl});

  final String relayUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = pluginConfigSnippet(relayUrl: relayUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.pushSetupTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(context.l10n.pushSetupStep1, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
                  child: SelectableText(
                    snippet,
                    key: const Key('push-snippet'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.mono,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('push-copy'),
                    tooltip: context.l10n.copy,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final copied = context.l10n.copied;
                      await Clipboard.setData(ClipboardData(text: snippet));
                      messenger.showSnackBar(SnackBar(content: Text(copied)));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.pushSetupStep2, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
