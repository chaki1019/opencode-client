/// The checked-out branch and the repository's default branch
/// (`GET /api/vcs`).
class VcsBranch {
  const VcsBranch({this.current, this.defaultBranch});

  final String? current;
  final String? defaultBranch;
}

/// What a diff compares.
enum DiffMode {
  /// Uncommitted changes in the working tree.
  working,

  /// Everything on this branch compared with the default branch.
  branch,
}

/// One changed file (`GET /api/vcs/status`, `GET /api/vcs/diff`).
class FileChange {
  const FileChange({
    required this.file,
    this.additions = 0,
    this.deletions = 0,
    this.status,
    this.patch,
  });

  static FileChange? tryParse(Object? json) {
    if (json is! Map || json['file'] is! String) return null;
    return FileChange(
      file: json['file'] as String,
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
      patch: json['patch'] as String?,
    );
  }

  /// Path relative to the project directory.
  final String file;
  final int additions;
  final int deletions;

  /// Free-form, such as `modified`, `added` or `deleted`.
  final String? status;

  /// Unified diff text, when loaded from the diff endpoint.
  final String? patch;
}

/// An MCP server configured for the project (`GET /api/mcp`).
class McpServer {
  const McpServer({required this.name, required this.status, this.error});

  static McpServer? tryParse(Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    final status = json['status'];
    return McpServer(
      name: json['name'] as String,
      status: switch (status) {
        final Map<Object?, Object?> s => s['status'] as String? ?? 'unknown',
        final String s => s,
        _ => 'unknown',
      },
      error: status is Map ? status['error'] as String? : null,
    );
  }

  final String name;

  /// `connected`, `disconnected`, `disabled`, `failed`, `needs_auth`,
  /// `needs_client_registration`, or another value from a newer server.
  final String status;
  final String? error;

  bool get isConnected => status == 'connected';

  String get statusLabel => switch (status) {
    'connected' => '接続中',
    'disconnected' => '未接続',
    'disabled' => '無効',
    'failed' => '失敗',
    'needs_auth' => '認証が必要',
    'needs_client_registration' => 'クライアント登録が必要',
    _ => status,
  };
}
