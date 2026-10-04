import 'dart:async';

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
    // A background connection reconnects with the new details.
    if (ref.read(connectionProvider)?.server.id != server.id &&
        ref.read(connectionPoolProvider).containsKey(server.id)) {
      final pool = ref.read(connectionPoolProvider.notifier)..remove(server.id);
      unawaited(pool.connectSaved());
    }
  }

  Future<void> forget(String id) async {
    final updated = (await future).where((s) => s.id != id).toList();
    await _store.saveServers(updated);
    await _store.deletePassword(id);
    state = AsyncData(updated);
    if (ref.read(connectionProvider)?.server.id != id) {
      ref.read(connectionPoolProvider.notifier).remove(id);
    }
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

/// One saved server's place in the pool of open connections: connecting
/// while both fields are null, then either connected or failed.
class ServerLink {
  const ServerLink.connecting() : connection = null, error = null;

  const ServerLink.connected(ActiveConnection this.connection) : error = null;

  const ServerLink.failed(Object this.error) : connection = null;

  final ActiveConnection? connection;
  final Object? error;

  bool get isConnecting => connection == null && error == null;
}

/// Every server the app keeps a connection to, by server ID. The one on
/// screen is [connectionProvider]; the others stay connected in the
/// background so switching is instant and their progress shows in the
/// drawer.
class ConnectionPoolNotifier extends Notifier<Map<String, ServerLink>> {
  @override
  Map<String, ServerLink> build() => const {};

  void _set(String id, ServerLink link) => state = {...state, id: link};

  void add(ActiveConnection connection) =>
      _set(connection.server.id, ServerLink.connected(connection));

  /// Connects to each saved server not in the pool yet. Failures stay in
  /// the pool, so the drawer can say which servers can't be reached.
  Future<void> connectSaved() async {
    final servers = await ref.read(savedServersProvider.future);
    final store = ref.read(serverStoreProvider);
    final factory = ref.read(clientFactoryProvider);
    await Future.wait([
      for (final server in servers)
        if (!state.containsKey(server.id))
          () async {
            _set(server.id, const ServerLink.connecting());
            try {
              final client = factory(
                server,
                await store.readPassword(server.id),
              );
              final health = await client.connect();
              if (!ref.mounted || !state.containsKey(server.id)) return;
              add(
                ActiveConnection(
                  server: server,
                  client: client,
                  health: health,
                ),
              );
            } catch (e) {
              if (!ref.mounted || !state.containsKey(server.id)) return;
              _set(server.id, ServerLink.failed(e));
            }
          }(),
    ]);
  }

  void remove(String id) => state = {...state}..remove(id);

  void clear() => state = const {};
}

final connectionPoolProvider =
    NotifierProvider<ConnectionPoolNotifier, Map<String, ServerLink>>(
      ConnectionPoolNotifier.new,
    );

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
    final opened = saved == null
        ? connection
        : ActiveConnection(
            server: saved,
            client: connection.client,
            health: connection.health,
          );
    final pool = ref.read(connectionPoolProvider.notifier)..add(opened);
    state = opened;
    // The other saved servers connect in the background.
    unawaited(pool.connectSaved());
  }

  /// Probes and opens in one step.
  Future<void> connect(ServerConfig server, String password) async =>
      open(await probe(server, password), password);

  /// Switches to a saved server, reusing its background connection when
  /// there is one.
  Future<void> connectSaved(ServerConfig server) async {
    final password = await ref
        .read(serverStoreProvider)
        .readPassword(server.id);
    final pooled = ref.read(connectionPoolProvider)[server.id]?.connection;
    await (pooled == null ? connect(server, password) : open(pooled, password));
  }

  /// Closes every connection and goes back to the connect screen.
  void disconnect() {
    ref.read(connectionPoolProvider.notifier).clear();
    state = null;
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ActiveConnection?>(
      ConnectionNotifier.new,
    );
