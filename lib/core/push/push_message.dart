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

/// The relay saying that a session's notifications of [kinds] were dealt
/// with elsewhere (answered at the computer, opened in the TUI, or a new
/// turn started), so the phone removes them without showing anything.
class PushResolved {
  const PushResolved({
    required this.keyId,
    required this.sessionId,
    required this.kinds,
  });

  /// Reads the relay's data payload; null when it is not a resolution.
  static PushResolved? fromData(Map<String, dynamic> data) {
    final keyId = data['keyId'];
    final session = data['session'];
    final kinds = data['kinds'];
    if (data['type'] != 'resolved' ||
        keyId is! String ||
        session is! String ||
        kinds is! String) {
      return null;
    }
    final names = PushKind.values.asNameMap();
    return PushResolved(
      keyId: keyId,
      sessionId: session,
      kinds: {for (final k in kinds.split(',')) ?names[k]},
    );
  }

  final String keyId;
  final String sessionId;
  final Set<PushKind> kinds;

  /// Whether this resolves the notification for [message].
  bool covers(PushMessage message) =>
      message.keyId == keyId &&
      message.sessionId == sessionId &&
      kinds.contains(message.kind);
}
