/// How the user answers a permission request.
enum PermissionDecision {
  once,
  always,
  reject;

  String get wireValue => name;
}

/// A tool waiting for the user's permission (`GET
/// /api/session/:id/permission`, `permission.asked`).
class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.sessionId,
    required this.action,
    this.resources = const [],
    this.save = const [],
    this.metadata = const {},
    this.message,
    this.messageId,
    this.callId,
  });

  /// Returns null when [json] lacks the identifying fields.
  static PermissionRequest? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sessionId = json['sessionID'];
    final action = json['action'];
    if (id is! String || sessionId is! String || action is! String) {
      return null;
    }
    final metadata = json['metadata'];
    final source = json['source'];
    return PermissionRequest(
      id: id,
      sessionId: sessionId,
      action: action,
      resources: _strings(json['resources']),
      save: _strings(json['save']),
      metadata: metadata is Map ? metadata.cast<String, dynamic>() : const {},
      message: json['message'] as String?,
      messageId: source is Map ? source['messageID'] as String? : null,
      callId: source is Map ? source['id'] as String? : null,
    );
  }

  final String id;
  final String sessionId;

  /// What the tool wants to do, such as `bash`, `edit` or `read`.
  final String action;

  /// Patterns this request covers.
  final List<String> resources;

  /// Patterns that "always allow" would remember.
  final List<String> save;
  final Map<String, dynamic> metadata;
  final String? message;

  /// The assistant message and tool call that asked.
  final String? messageId;
  final String? callId;

  /// A human-readable line about what is being allowed.
  String? get description {
    for (final value in [
      message,
      metadata['description'],
      metadata['command'],
      metadata['filePath'],
      metadata['path'],
    ]) {
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static List<String> _strings(Object? value) => [
    for (final item in value is List ? value : const [])
      if (item is String) item,
  ];
}

/// One item of the agent's todo list.
class TodoItem {
  const TodoItem({required this.content, required this.status, this.priority});

  final String content;

  /// `pending`, `in_progress`, `completed` or `cancelled`.
  final String status;
  final String? priority;

  bool get isDone => status == 'completed' || status == 'cancelled';
  bool get isActive => status == 'in_progress';

  /// Reads the `todos` array a todo-writing tool was called with. Returns
  /// null when [input] has none.
  static List<TodoItem>? fromToolInput(Map<String, dynamic> input) {
    final todos = input['todos'];
    if (todos is! List) return null;
    return [
      for (final item in todos)
        if (item is Map && item['content'] is String)
          TodoItem(
            content: item['content'] as String,
            status: item['status'] as String? ?? 'pending',
            priority: item['priority'] as String?,
          ),
    ];
  }

  static bool isTodoTool(String name) =>
      name == 'todowrite' || name == 'todo_write';
}
