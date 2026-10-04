import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

/// How the connected server answered a fresh health check.
class ServerCheck {
  const ServerCheck({this.health, this.latency, this.error});

  final ServerHealth? health;

  /// Round trip of the health request.
  final Duration? latency;
  final Object? error;
}

/// Re-runs the health check against the connected server, timing it.
final serverCheckProvider = FutureProvider.autoDispose<ServerCheck?>((
  ref,
) async {
  final client = ref.watch(connectionProvider)?.client;
  if (client == null) return null;
  final watch = Stopwatch()..start();
  try {
    final health = await client.connect();
    return ServerCheck(health: health, latency: watch.elapsed);
  } catch (e) {
    return ServerCheck(error: e);
  }
});

/// The MCP servers OpenCode knows for the server's own directory.
final diagnosticsMcpProvider = FutureProvider.autoDispose<List<McpServer>>((
  ref,
) async {
  final client = ref.watch(connectionProvider)?.client;
  if (client == null) return const [];
  final directory = await client.serverDirectory();
  return client.listMcpServers(directory: directory);
});
