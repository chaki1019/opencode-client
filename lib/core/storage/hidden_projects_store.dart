import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Projects the user took off the project list, per server. OpenCode has no
/// way to delete a project, so hiding one only changes what this app shows.
class HiddenProjectsStore {
  HiddenProjectsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'projects.hidden.v1';

  final FlutterSecureStorage _storage;

  /// Hidden project directories, by server URL.
  Future<Map<String, Set<String>>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: {for (final d in value as List) d as String},
    };
  }

  Future<void> save(Map<String, Set<String>> hidden) => _storage.write(
    key: _key,
    value: jsonEncode({
      for (final MapEntry(:key, :value) in hidden.entries)
        if (value.isNotEmpty) key: value.toList(),
    }),
  );
}
