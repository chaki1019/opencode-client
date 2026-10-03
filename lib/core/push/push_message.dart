/// What the OpenCode plugin reported; matches the relay's `kind`.
enum PushKind { completed, failed, permission, question }

/// A notification from the relay. [keyId] identifies the pairing (and so
/// the saved server) it was sent for; [enc] is the encrypted content, which
/// only that pairing's key opens.
class PushMessage {
  const PushMessage({
    required this.kind,
    required this.keyId,
    required this.sessionId,
    required this.enc,
  });

  /// Reads the relay's FCM data payload; null when it is not ours.
  static PushMessage? fromData(Map<String, dynamic> data) {
    final keyId = data['keyId'];
    final sessionId = data['sessionID'];
    if (keyId is! String || sessionId is! String) return null;
    return PushMessage(
      kind: PushKind.values.asNameMap()[data['kind']] ?? PushKind.completed,
      keyId: keyId,
      sessionId: sessionId,
      enc: data['enc'] is String ? data['enc'] as String : '',
    );
  }

  final PushKind kind;
  final String keyId;
  final String sessionId;
  final String enc;

  /// A test notification has no session to open.
  bool get hasSession => sessionId.isNotEmpty;

  Map<String, String> toData() => {
    'kind': kind.name,
    'keyId': keyId,
    'sessionID': sessionId,
    'enc': enc,
  };
}
