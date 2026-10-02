import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/opencode_client.dart';
import '../../core/discovery/server_discovery.dart';
import '../../core/models/server_config.dart';
import '../../core/storage/server_store.dart';

final serverStoreProvider = Provider<ServerStore>((ref) => ServerStore());

/// Builds a client; overridden in tests to inject a fake transport.
final clientFactoryProvider =
    Provider<OpenCodeClient Function(ServerConfig server, String password)>(
      (ref) =>
          (server, password) => OpenCodeClient(
            baseUrl: server.baseUrl,
            username: server.username,
            password: password,
          ),
    );

class SavedServersNotifier extends AsyncNotifier<List<ServerConfig>> {
  ServerStore get _store => ref.read(serverStoreProvider);

  @override
  Future<List<ServerConfig>> build() => _store.loadServers();

  /// Inserts or updates [server] and moves it to the top (most recent).
  Future<void> remember(ServerConfig server, String password) async {
    final current = await future;
    final updated = [server, ...current.where((s) => s.id != server.id)];
    await _store.saveServers(updated);
    await _store.writePassword(server.id, password);
    state = AsyncData(updated);
  }

  /// Replaces the saved server with the same id, keeping its place in the
  /// list.
  Future<void> edit(ServerConfig server, String password) async {
    final updated = [
      for (final s in await future) s.id == server.id ? server : s,
    ];
    await _store.saveServers(updated);
    await _store.writePassword(server.id, password);
    state = AsyncData(updated);
  }

  Future<void> forget(String id) async {
    final updated = (await future).where((s) => s.id != id).toList();
    await _store.saveServers(updated);
    await _store.deletePassword(id);
    state = AsyncData(updated);
  }

  /// Returns the saved server matching URL and username, so reconnecting
  /// with the same details does not create duplicates.
  Future<ServerConfig?> find(String baseUrl, String username) async =>
      (await future)
          .where((s) => s.baseUrl == baseUrl && s.username == username)
          .firstOrNull;
}

/// Overridden in tests; the platform plugin is not available there.
final serverDiscoveryProvider = Provider<ServerDiscovery>(
  (ref) => NsdServerDiscovery(),
);

/// OpenCode servers announced on the local network. Browsing runs only
/// while something (the connect screen) is listening.
final discoveredServersProvider =
    StreamProvider.autoDispose<List<DiscoveredServer>>(
      (ref) => ref.watch(serverDiscoveryProvider).watch(),
    );

final savedServersProvider =
    AsyncNotifierProvider<SavedServersNotifier, List<ServerConfig>>(
      SavedServersNotifier.new,
    );

class ActiveConnection {
  const ActiveConnection({
    required this.server,
    required this.client,
    required this.health,
  });

  final ServerConfig server;
  final OpenCodeClient client;
  final ServerHealth health;
}

class ConnectionNotifier extends Notifier<ActiveConnection?> {
  @override
  ActiveConnection? build() => null;

  /// Probes the server; on success remembers it and becomes the active
  /// connection. Throws [OpenCodeApiException] on failure.
  Future<void> connect(ServerConfig server, String password) async {
    final client = ref.read(clientFactoryProvider)(server, password);
    final health = await client.connect();
    await ref.read(savedServersProvider.notifier).remember(server, password);
    state = ActiveConnection(server: server, client: client, health: health);
  }

  Future<void> connectSaved(ServerConfig server) async {
    final password = await ref
        .read(serverStoreProvider)
        .readPassword(server.id);
    await connect(server, password);
  }

  void disconnect() => state = null;
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ActiveConnection?>(
      ConnectionNotifier.new,
    );
