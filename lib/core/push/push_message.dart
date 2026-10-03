import 'dart:convert';

import 'package:crypto/crypto.dart';

/// What the OpenCode plugin reported; matches the relay's `kind`.
enum PushKind { completed, failed, permission, question }

/// A notification from the relay. [keyId] identifies the pairing key (and
/// so the saved server) it was sent for.
class PushMessage {
  const PushMessage({
    required this.kind,
    required this.keyId,
    required this.sessionId,
    required this.directory,
    this.title,
    this.body,
  });

  /// Reads the relay's FCM data payload; null when it is not ours.
  static PushMessage? fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final keyId = data['keyId'];
    final sessionId = data['sessionID'];
    if (keyId is! String || sessionId is! String || sessionId.isEmpty) {
      return null;
    }
    return PushMessage(
      kind: PushKind.values.asNameMap()[data['kind']] ?? PushKind.completed,
      keyId: keyId,
      sessionId: sessionId,
      directory: data['directory'] is String ? data['directory'] as String : '',
      title: title,
      body: body,
    );
  }

  final PushKind kind;
  final String keyId;
  final String sessionId;
  final String directory;
  final String? title;
  final String? body;
}

/// The relay's id for a pairing key: hex SHA-256, so the raw key never
/// travels with a notification.
String pairingKeyId(String key) => sha256.convert(utf8.encode(key)).toString();
