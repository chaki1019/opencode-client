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
}

/// A file or folder in the project (`GET /api/fs/list`, `/api/fs/find`).
class FsEntry {
  const FsEntry({required this.path, required this.isDirectory});

  static FsEntry? tryParse(Object? json) {
    if (json is! Map || json['path'] is! String) return null;
    return FsEntry(
      path: json['path'] as String,
      isDirectory: json['type'] == 'directory',
    );
  }

  /// Relative to the project directory.
  final String path;
  final bool isDirectory;

  String get name {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return trimmed.substring(trimmed.lastIndexOf('/') + 1);
  }
}

/// A file's contents (`GET /api/fs/read/:path`). [text] is set when the
/// bytes are UTF-8 text and not an image.
class FileContent {
  const FileContent({required this.bytes, this.mimeType, this.text});

  final List<int> bytes;
  final String? mimeType;
  final String? text;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
}

/// A checkout of the project (`GET /api/worktree`): the main one, or a copy
/// the server manages with `git worktree`.
class Worktree {
  const Worktree({required this.directory, this.strategy});

  static Worktree? tryParse(Object? json) {
    if (json is! Map || json['directory'] is! String) return null;
    return Worktree(
      directory: json['directory'] as String,
      strategy: json['strategy'] as String?,
    );
  }

  final String directory;
  final String? strategy;

  /// The project's own checkout.
  bool get isMain => strategy == null;

  /// A copy the server created and can remove.
  bool get isManaged => strategy == 'git' || strategy == 'git_worktree';

  String get name {
    final parts = directory.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? directory : parts.last;
  }
}

/// A terminal process on the server (`GET /api/pty`).
class Pty {
  const Pty({
    required this.id,
    this.title,
    this.command,
    this.cwd,
    this.status,
    this.exitCode,
  });

  static Pty? tryParse(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return Pty(
      id: json['id'] as String,
      title: json['title'] as String?,
      command: json['command'] as String?,
      cwd: json['cwd'] as String?,
      status: json['status'] as String?,
      exitCode: (json['exitCode'] as num?)?.toInt(),
    );
  }

  final String id;
  final String? title;
  final String? command;
  final String? cwd;

  /// `running` or `exited`.
  final String? status;
  final int? exitCode;

  bool get isRunning => status != 'exited';

  String get displayTitle =>
      (title?.trim().isNotEmpty ?? false) ? title!.trim() : (command ?? id);
}
