import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../live/live_widgets.dart';
import 'mcp_providers.dart';

/// The project's MCP servers with a switch to connect or disconnect each.
class McpScreen extends ConsumerWidget {
  const McpScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mcpServersProvider(project.directory);
    final servers = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(project.displayName),
        bottom: const LiveStatusBanner(),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: servers.when(
          data: (list) => list.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [Center(child: Text('MCP サーバーは設定されていません'))],
                )
              : ListView(
                  children: [
                    for (final server in list)
                      _McpTile(directory: project.directory, server: server),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('MCP サーバーを読み込めませんでした: $e')],
          ),
        ),
      ),
    );
  }
}

class _McpTile extends ConsumerStatefulWidget {
  const _McpTile({required this.directory, required this.server});

  final String directory;
  final McpServer server;

  @override
  ConsumerState<_McpTile> createState() => _McpTileState();
}

class _McpTileState extends ConsumerState<_McpTile> {
  bool _busy = false;

  Future<void> _toggle() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(mcpServersProvider(widget.directory).notifier)
          .toggle(widget.server);
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('切り替えられませんでした: ${e.detail}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = widget.server;
    final problem =
        server.status == 'failed' || server.status.startsWith('needs_');
    return ListTile(
      key: ValueKey('mcp-${server.name}'),
      leading: Icon(
        server.isConnected ? Icons.power : Icons.power_off,
        color: server.isConnected
            ? Colors.green
            : problem
            ? theme.colorScheme.error
            : theme.colorScheme.outline,
      ),
      title: Text(server.name),
      subtitle: Text(
        server.error == null
            ? server.statusLabel
            : '${server.statusLabel}: ${server.error}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Switch(
        value: server.isConnected,
        onChanged: _busy ? null : (_) => _toggle(),
      ),
    );
  }
}
