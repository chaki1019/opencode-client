import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Push state for one saved server. [key] is the pairing key the user puts
/// in the OpenCode plugin's options; [token] is the FCM token last
/// registered with it, kept so it can be unregistered.
class PushPairing {
  const PushPairing({required this.key, this.enabled = false, this.token});

  final String key;
  final bool enabled;
  final String? token;

  PushPairing copyWith({bool? enabled, String? token}) => PushPairing(
    key: key,
    enabled: enabled ?? this.enabled,
    token: token ?? this.token,
  );

  /// 32 random bytes, base64url without padding (43 characters).
  static String newKey([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

/// Keeps each server's pairing in secure storage next to its password.
class PushStore {
  PushStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static String _key(String serverId) => 'server.$serverId.push';

  final FlutterSecureStorage _storage;

  Future<PushPairing?> load(String serverId) async {
    final raw = await _storage.read(key: _key(serverId));
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return PushPairing(
      key: json['key'] as String,
      enabled: json['enabled'] as bool? ?? false,
      token: json['token'] as String?,
    );
  }

  Future<void> save(String serverId, PushPairing pairing) => _storage.write(
    key: _key(serverId),
    value: jsonEncode({
      'key': pairing.key,
      'enabled': pairing.enabled,
      'token': ?pairing.token,
    }),
  );

  Future<void> delete(String serverId) => _storage.delete(key: _key(serverId));
}
