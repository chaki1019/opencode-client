class ServerHealth {
  const ServerHealth({required this.version, required this.pid});

  final String version;
  final int pid;
}

class OpenCodeApiException implements Exception {
  const OpenCodeApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

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
