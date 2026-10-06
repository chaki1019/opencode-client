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
      unawaited(ref.read(connectionPoolProvider.notifier).reconnect(server));
    }
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
/// Both run only while something (the connect screen, after the user taps
/// search) is listening; invalidate to scan again.
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

/// One server's place in the pool of open connections: connecting while
/// both fields are null, then either connected or failed.
class ServerLink {
  const ServerLink.connecting(this.server) : connection = null, error = null;

  ServerLink.connected(ActiveConnection this.connection)
    : server = connection.server,
      error = null;

  const ServerLink.failed(this.server, Object this.error) : connection = null;

  final ServerConfig server;
  final ActiveConnection? connection;
  final Object? error;

  bool get isConnecting => connection == null && error == null;
}

/// Every server the user connected to in this run of the app, by server ID
/// in the order they were first connected. The one on screen is
/// [connectionProvider]; the others stay connected in the background so
/// switching is instant and their progress shows in the drawer.
class ConnectionPoolNotifier extends Notifier<Map<String, ServerLink>> {
  @override
  Map<String, ServerLink> build() => const {};

  // Replacing an existing key keeps its place in the map's order.
  void _set(String id, ServerLink link) => state = {...state, id: link};

  void add(ActiveConnection connection) =>
      _set(connection.server.id, ServerLink.connected(connection));

  /// Connects to [server] again, with its saved password, keeping its place
  /// in the pool. A failure stays in the pool, so the drawer can say the
  /// server can't be reached.
  Future<void> reconnect(ServerConfig server) async {
    _set(server.id, ServerLink.connecting(server));
    try {
      final client = ref.read(clientFactoryProvider)(
        server,
        await ref.read(serverStoreProvider).readPassword(server.id),
      );
      final health = await client.connect();
      if (!ref.mounted || !state.containsKey(server.id)) return;
      add(ActiveConnection(server: server, client: client, health: health));
    } catch (e) {
      if (!ref.mounted || !state.containsKey(server.id)) return;
      _set(server.id, ServerLink.failed(server, e));
    }
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
    ref.read(connectionPoolProvider.notifier).add(opened);
    state = opened;
  }

  /// Probes and opens in one step.
  Future<void> connect(ServerConfig server, String password) async =>
      open(await probe(server, password), password);

  /// Switches to a saved or already connected server, reusing its
  /// background connection when there is one.
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

/// The servers the user connected to, for the drawer, in the order they
/// were first connected; switching between them never reorders the list.
/// Whether a server is saved does not matter, but a saved one shows its
/// saved details, so a rename shows at once.
final connectedServersProvider = Provider<List<ServerConfig>>((ref) {
  final pool = ref.watch(connectionPoolProvider);
  final saved = ref.watch(savedServersProvider).value ?? const [];
  return [
    for (final link in pool.values)
      saved.where((s) => s.id == link.server.id).firstOrNull ?? link.server,
  ];
});

/// The servers whose notifications can be managed: the connected ones,
/// then the saved ones not connected in this run.
final listedServersProvider = Provider<List<ServerConfig>>((ref) {
  final connected = ref.watch(connectedServersProvider);
  final saved = ref.watch(savedServersProvider).value ?? const [];
  return [
    ...connected,
    for (final s in saved)
      if (!connected.any((c) => c.id == s.id)) s,
  ];
});

/// The client for the server with [id]: its connection in the pool, or
/// the one on screen. Null while it is not connected.
final serverClientProvider = Provider.family<OpenCodeClient?, String>((
  ref,
  id,
) {
  final pooled = ref.watch(
    connectionPoolProvider.select((pool) => pool[id]?.connection?.client),
  );
  if (pooled != null) return pooled;
  final current = ref.watch(connectionProvider);
  return current?.server.id == id ? current!.client : null;
});
