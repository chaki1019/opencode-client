import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

/// Keys derived from a pairing key, matching push/plugin/opencode-push.js.
/// [auth] is what the relay sees; [encKey] never leaves the phone and the
/// computer.
class PushKeys {
  const PushKeys({required this.auth, required this.encKey});

  final String auth;
  final List<int> encKey;

  /// The relay's id for these keys (hex SHA-256 of [auth]); it comes back
  /// with every notification.
  String get keyId => sha256.convert(utf8.encode(auth)).toString();

  static Future<PushKeys> derive(String pairingKey) async {
    return PushKeys(
      auth: _base64Url(await _hkdf(pairingKey, 'opencode-push/auth')),
      encKey: await _hkdf(pairingKey, 'opencode-push/enc'),
    );
  }

  static Future<List<int>> _hkdf(String key, String info) async {
    final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(utf8.encode(key)),
      nonce: const [],
      info: utf8.encode(info),
    );
    return derived.extractBytes();
  }
}

/// What a notification says once decrypted.
class PushContent {
  const PushContent({required this.project, this.title, this.detail});

  factory PushContent.fromJson(Map<String, dynamic> json) => PushContent(
    project: json['project'] is String ? json['project'] as String : '',
    title: json['title'] is String ? json['title'] as String : null,
    detail: json['detail'] is String ? json['detail'] as String : null,
  );

  final String project;
  final String? title;
  final String? detail;

  Map<String, Object?> toJson() => {
    'project': project,
    'title': ?title,
    'detail': ?detail,
  };
}

final _aes = AesGcm.with256bits();

List<int> _aad(String kind, String sessionId) =>
    utf8.encode('$kind:$sessionId');

/// Decrypts a relay payload; null when it was not sealed with [encKey] or
/// was altered (including its kind or session).
Future<PushContent?> openPushContent({
  required List<int> encKey,
  required String kind,
  required String sessionId,
  required String enc,
}) async {
  try {
    final raw = base64Url.decode(base64Url.normalize(enc));
    if (raw.length < 12 + 16) return null;
    final box = SecretBox(
      raw.sublist(12, raw.length - 16),
      nonce: raw.sublist(0, 12),
      mac: Mac(raw.sublist(raw.length - 16)),
    );
    final plain = await _aes.decrypt(
      box,
      secretKey: SecretKey(encKey),
      aad: _aad(kind, sessionId),
    );
    final json = jsonDecode(utf8.decode(plain));
    return json is Map<String, dynamic> ? PushContent.fromJson(json) : null;
  } on Object {
    return null;
  }
}

/// Encrypts [content] the way the plugin does (used for the test
/// notification).
Future<String> sealPushContent({
  required List<int> encKey,
  required String kind,
  required String sessionId,
  required PushContent content,
}) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(content.toJson())),
    secretKey: SecretKey(encKey),
    aad: _aad(kind, sessionId),
  );
  return _base64Url(box.concatenation());
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
