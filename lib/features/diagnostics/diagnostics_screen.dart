import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/layout.dart';
import '../../core/events/event_stream.dart';
import '../../core/models/project_tools.dart';
import '../../core/push/computer_plugin.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import '../push/push_providers.dart';
import '../update/update_providers.dart';
import 'diagnostics_providers.dart';

enum _Level { ok, warning, error, neutral }

/// One checked item: what it is, how it went, and a short value.
class _Row {
  const _Row(this.label, this.value, this.level, {this.onTap});

  final String label;
  final String value;
  final _Level level;
  final VoidCallback? onTap;
}

/// Shows whether the parts the app depends on work: the server, live
/// updates, the push plugin and MCP servers. The whole report can be
/// copied, for example into a support email.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connection = ref.watch(connectionProvider);
    if (connection == null) return const SizedBox.shrink();

    final serverCheck = ref.watch(serverCheckProvider);
    ref.watch(eventStreamStatusProvider);
    final streamStatus = ref.watch(eventStreamProvider)?.status;
    final plugin = ref.watch(computerPluginProvider(connection.server.id));
    final mcp = ref.watch(diagnosticsMcpProvider);
    final appVersion = ref.watch(_appVersionProvider).value;
    final checking = l10n.diagnosticsChecking;

    final sections = <(String, List<_Row>)>[
      (
        l10n.diagnosticsServer,
        [
          _Row(
            l10n.diagnosticsAddress,
            connection.server.baseUrl,
            _Level.neutral,
          ),
          switch (serverCheck) {
            AsyncData(value: ServerCheck(:final health?, :final latency)) =>
              _Row(
                l10n.diagnosticsHealth,
                l10n.diagnosticsHealthOk(
                  health.version,
                  latency?.inMilliseconds ?? 0,
                ),
                _Level.ok,
              ),
            AsyncData(value: ServerCheck(:final error?)) => _Row(
              l10n.diagnosticsHealth,
              l10n.diagnosticsHealthFailed(error),
              _Level.error,
            ),
            _ => _Row(l10n.diagnosticsHealth, checking, _Level.neutral),
          },
        ],
      ),
      (
        l10n.diagnosticsLive,
        [
          switch (streamStatus) {
            EventStreamStatus.connected => _Row(
              l10n.diagnosticsLiveUpdates,
              l10n.diagnosticsLiveConnected,
              _Level.ok,
            ),
            EventStreamStatus.connecting ||
            EventStreamStatus.reconnecting => _Row(
              l10n.diagnosticsLiveUpdates,
              l10n.reconnecting,
              _Level.warning,
            ),
            _ => _Row(
              l10n.diagnosticsLiveUpdates,
              l10n.diagnosticsLiveStopped,
              _Level.error,
            ),
          },
        ],
      ),
      (
        l10n.diagnosticsPush,
        [_pluginRow(l10n, plugin, () => context.push('/push'))],
      ),
      (
        'MCP',
        switch (mcp) {
          AsyncData(value: final servers) when servers.isEmpty => [
            _Row(l10n.diagnosticsMcpNone, '', _Level.neutral),
          ],
          AsyncData(value: final servers) => [
            for (final s in servers) _mcpRow(l10n, s),
          ],
          AsyncError(:final error) => [
            _Row('MCP', l10n.diagnosticsHealthFailed(error), _Level.error),
          ],
          _ => [_Row('MCP', checking, _Level.neutral)],
        },
      ),
      (
        l10n.diagnosticsApp,
        [
          _Row(l10n.diagnosticsAppVersion, appVersion ?? '', _Level.neutral),
          _Row(
            l10n.diagnosticsOs,
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            _Level.neutral,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagnosticsTitle),
        actions: [
          IconButton(
            key: const Key('diagnostics-refresh'),
            tooltip: l10n.diagnosticsRecheck,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(serverCheckProvider);
              ref.invalidate(diagnosticsMcpProvider);
              ref.invalidate(computerPluginProvider(connection.server.id));
            },
          ),
          IconButton(
            key: const Key('diagnostics-copy'),
            tooltip: l10n.diagnosticsCopy,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final copied = l10n.copied;
              await Clipboard.setData(ClipboardData(text: _report(sections)));
              messenger.showSnackBar(SnackBar(content: Text(copied)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          readableSide(context),
          0,
          readableSide(context),
          24,
        ),
        children: [
          for (final (title, rows) in sections) ...[
            _SectionHeader(title),
            for (final row in rows) _RowTile(row),
          ],
        ],
      ),
    );
  }

  static _Row _pluginRow(
    AppLocalizations l10n,
    AsyncValue<ComputerPluginCheck?> check,
    VoidCallback open,
  ) {
    final label = l10n.diagnosticsPlugin;
    final (value, level) = switch (check) {
      AsyncData(value: final check?) => switch (check.status) {
        ComputerPluginStatus.active => (l10n.pushComputerActive, _Level.ok),
        ComputerPluginStatus.failed => (
          l10n.pushComputerFailed(check.error ?? ''),
          _Level.error,
        ),
        ComputerPluginStatus.otherKey => (
          l10n.pushComputerOtherKey,
          _Level.error,
        ),
        ComputerPluginStatus.notLoaded => (
          l10n.pushComputerNotLoaded,
          _Level.warning,
        ),
        ComputerPluginStatus.missing => (
          l10n.pushComputerMissing,
          _Level.neutral,
        ),
      },
      AsyncLoading() => (l10n.diagnosticsChecking, _Level.neutral),
      _ => (l10n.pushComputerUnknown, _Level.neutral),
    };
    return _Row(label, value, level, onTap: open);
  }

  static _Row _mcpRow(AppLocalizations l10n, McpServer server) {
    final level = switch (server.status) {
      'connected' => _Level.ok,
      'disabled' || 'disconnected' => _Level.neutral,
      'failed' => _Level.error,
      _ => _Level.warning,
    };
    final value = [server.status, ?server.error].join(': ');
    return _Row(server.name, value, level);
  }
}

/// The checks as plain text, one `label: value` line per row under each
/// section title.
String _report(List<(String, List<_Row>)> sections) {
  final lines = <String>[];
  for (final (title, rows) in sections) {
    if (lines.isNotEmpty) lines.add('');
    lines.add('[$title]');
    for (final row in rows) {
      lines.add(row.value.isEmpty ? row.label : '${row.label}: ${row.value}');
    }
  }
  return lines.join('\n');
}

final _appVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  final info = await ref.watch(packageInfoProvider);
  return '${info.version} (${info.buildNumber})';
});

class _RowTile extends StatelessWidget {
  const _RowTile(this.row);

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (row.level) {
      _Level.ok => (Icons.check_circle_outline, colors.primary),
      _Level.warning => (Icons.warning_amber_outlined, colors.tertiary),
      _Level.error => (Icons.error_outline, colors.error),
      _Level.neutral => (Icons.circle_outlined, colors.onSurfaceVariant),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(row.label),
      subtitle: row.value.isEmpty ? null : Text(row.value),
      trailing: row.onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: row.onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
