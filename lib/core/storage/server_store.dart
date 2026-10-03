import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/server_config.dart';

/// Persists saved servers (Keychain on iOS, Keystore-backed on Android).
/// Passwords are stored under their own key so the server list can be read
/// without touching credentials.
class ServerStore {
  ServerStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _serversKey = 'servers.v1';
  static const _declinedKey = 'servers.declined.v1';
  static String _passwordKey(String id) => 'server.$id.password';

  final FlutterSecureStorage _storage;

  Future<List<ServerConfig>> loadServers() async {
    final raw = await _storage.read(key: _serversKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return [
      for (final item in list)
        ServerConfig.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> saveServers(List<ServerConfig> servers) => _storage.write(
    key: _serversKey,
    value: jsonEncode([for (final s in servers) s.toJson()]),
  );

  Future<String> readPassword(String id) async =>
      await _storage.read(key: _passwordKey(id)) ?? '';

  Future<void> writePassword(String id, String password) =>
      _storage.write(key: _passwordKey(id), value: password);

  Future<void> deletePassword(String id) =>
      _storage.delete(key: _passwordKey(id));

  /// Servers the user chose not to save, as `username@baseUrl`.
  Future<Set<String>> loadDeclined() async {
    final raw = await _storage.read(key: _declinedKey);
    if (raw == null || raw.isEmpty) return {};
    return {for (final item in jsonDecode(raw) as List) item as String};
  }

  Future<void> saveDeclined(Set<String> keys) =>
      _storage.write(key: _declinedKey, value: jsonEncode(keys.toList()));
}
