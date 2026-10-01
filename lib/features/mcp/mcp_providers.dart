import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

/// MCP servers of a project directory. v2 sends no MCP events, so the list
/// is reloaded after every change.
class McpServersNotifier extends AsyncNotifier<List<McpServer>> {
  McpServersNotifier(this.directory);

  final String directory;

  @override
  Future<List<McpServer>> build() async {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const [];
    return client.listMcpServers(directory: directory);
  }

  /// Connects a disconnected server or disconnects a connected one.
  Future<void> toggle(McpServer server) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    try {
      await client.setMcpConnected(
        server.name,
        connected: !server.isConnected,
        directory: directory,
      );
    } finally {
      await _reload();
    }
  }

  Future<void> _reload() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null || !ref.mounted) return;
    try {
      final servers = await client.listMcpServers(directory: directory);
      if (ref.mounted) state = AsyncData(servers);
    } catch (_) {
      // Keep the last list; pull to refresh retries.
    }
  }
}

final mcpServersProvider = AsyncNotifierProvider.autoDispose
    .family<McpServersNotifier, List<McpServer>, String>(
      McpServersNotifier.new,
    );
