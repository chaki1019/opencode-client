import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Project directories the user marked on the project list, per server:
/// the ones taken off the list or the ones pinned to its top. OpenCode has
/// no way to delete or order projects, so these only change what this app
/// shows.
class ProjectDirectoriesStore {
  ProjectDirectoriesStore.hidden([FlutterSecureStorage? storage])
    : this._('projects.hidden.v1', storage);

  ProjectDirectoriesStore.pinned([FlutterSecureStorage? storage])
    : this._('projects.pinned.v1', storage);

  ProjectDirectoriesStore._(this._key, FlutterSecureStorage? storage)
    : _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;

  /// Marked project directories, by server URL.
  Future<Map<String, Set<String>>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: {for (final d in value as List) d as String},
    };
  }

  Future<void> save(Map<String, Set<String>> directories) => _storage.write(
    key: _key,
    value: jsonEncode({
      for (final MapEntry(:key, :value) in directories.entries)
        if (value.isNotEmpty) key: value.toList(),
    }),
  );
}
