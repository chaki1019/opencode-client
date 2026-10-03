import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/opencode_client.dart';
import '../../core/discovery/lan_scan.dart';
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

  static String _declineKey(String baseUrl, String username) =>
      '$username@$baseUrl';

  /// Whether the user already answered "don't save" for this server.
  Future<bool> isDeclined(String baseUrl, String username) async =>
      (await _store.loadDeclined()).contains(_declineKey(baseUrl, username));

  /// Remembers not to offer saving this server again.
  Future<void> decline(String baseUrl, String username) async {
    final declined = await _store.loadDeclined();
    if (declined.add(_declineKey(baseUrl, username))) {
      await _store.saveDeclined(declined);
    }
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

/// Probes the local network for servers that do not announce themselves.
final lanScanProvider = Provider<ServerDiscovery>((ref) => LanScanDiscovery());

/// OpenCode servers found on the local network, by mDNS and by scanning.
/// Both run only while something (the connect screen) is listening;
/// invalidate to scan again.
final discoveredServersProvider = StreamProvider.autoDispose<DiscoverySnapshot>(
  (ref) => mergeDiscoveries(
    browse: ref.watch(serverDiscoveryProvider).watch(),
    scan: ref.watch(lanScanProvider).watch(),
  ),
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

  /// Checks that [server] answers with [password] without switching to
  /// it, so the caller can ask about saving first. Throws
  /// [OpenCodeApiException] on failure.
  Future<ActiveConnection> probe(ServerConfig server, String password) async {
    final client = ref.read(clientFactoryProvider)(server, password);
    final health = await client.connect();
    return ActiveConnection(server: server, client: client, health: health);
  }

  /// Switches to a probed [connection]. A server that is already saved
  /// moves to the top of the list with the password that just worked;
  /// unsaved servers stay unsaved.
  Future<void> open(ActiveConnection connection, String password) async {
    final id = connection.server.id;
    final saved = (await ref.read(savedServersProvider.future))
        .where((s) => s.id == id)
        .firstOrNull;
    // The saved entry, not the probed one, keeps the name just given.
    if (saved != null) {
      await ref.read(savedServersProvider.notifier).remember(saved, password);
    }
    state = saved == null
        ? connection
        : ActiveConnection(
            server: saved,
            client: connection.client,
            health: connection.health,
          );
  }

  /// Probes and opens in one step.
  Future<void> connect(ServerConfig server, String password) async =>
      open(await probe(server, password), password);

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
