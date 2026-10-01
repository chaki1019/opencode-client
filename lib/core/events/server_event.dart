import 'dart:convert';

typedef Json = Map<String, dynamic>;

/// An event from the v2 stream (`GET /api/event`):
/// `{id, created, type, location: {directory, workspaceID}, data: {...}}`.
class ServerEvent {
  const ServerEvent({
    required this.type,
    this.id,
    this.created,
    this.directory,
    this.data = const {},
  });

  final String type;
  final String? id;

  /// Epoch milliseconds.
  final double? created;

  /// Directory the event belongs to, when the server scoped it.
  final String? directory;
  final Json data;

  /// Returns null when [raw] is not a JSON object with a string `type`.
  static ServerEvent? tryParse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final type = decoded['type'];
    if (type is! String) return null;
    final location = decoded['location'];
    final data = decoded['data'];
    final created = decoded['created'];
    return ServerEvent(
      type: type,
      id: decoded['id'] as String?,
      created: created is num ? created.toDouble() : null,
      directory: location is Map ? location['directory'] as String? : null,
      data: data is Map ? data.cast<String, dynamic>() : const {},
    );
  }

  String? get sessionId {
    final value = data['sessionID'];
    if (value is String) return value;
    final form = data['form'];
    return form is Map ? form['sessionID'] as String? : null;
  }

  /// The assistant message a streaming event belongs to.
  String? get assistantMessageId => data['assistantMessageID'] as String?;

  bool get isExecutionStarted =>
      type == 'session.execution.started' || type == 'session.retry.scheduled';

  bool get isExecutionTerminal => const {
    'session.execution.succeeded',
    'session.execution.failed',
    'session.execution.interrupted',
    'session.idle',
  }.contains(type);
}
