import 'dart:convert';

class ServerHealth {
  const ServerHealth({required this.version, required this.pid});

  final String version;
  final int pid;
}

/// Why a request never got an answer from the server.
enum NetworkFailure {
  /// The server did not answer in time.
  timeout,

  /// Nothing accepted the connection (wrong address, server not running,
  /// or not listening on the network).
  unreachable,
}

class OpenCodeApiException implements Exception {
  const OpenCodeApiException(this.message, {this.statusCode, this.network});

  final String message;
  final int? statusCode;
  final NetworkFailure? network;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// The server's explanation from a `{_tag, message}` or
  /// `{name, data: {message}}` error body, or the raw message.
  String get detail {
    try {
      final body = jsonDecode(message);
      if (body is Map) {
        final data = body['data'];
        final message =
            body['message'] ?? (data is Map ? data['message'] : null);
        if (message is String) return message;
      }
    } on FormatException {
      // Not JSON.
    }
    return message;
  }

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// The server answered but does not expose the OpenCode v2 HttpAPI
/// (`/api/...`). This app targets v2 only.
class UnsupportedServerException extends OpenCodeApiException {
  const UnsupportedServerException()
    : super('This server does not support the OpenCode v2 API');
}

/// A worktree has uncommitted changes; removing it needs `force`.
class WorktreeDirtyException extends OpenCodeApiException {
  const WorktreeDirtyException(super.message) : super(statusCode: 400);
}
