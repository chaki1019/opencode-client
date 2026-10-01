/// Session timeline records from `GET /api/session/:id/message`.
///
/// The v2 API returns a discriminated union keyed by `type`. Each record type
/// gets its own class so the UI can switch over them exhaustively. Records of
/// unknown types are skipped by [TimelineEntry.tryParse] so a newer server
/// does not break history loading.
library;

import 'session.dart';

typedef Json = Map<String, dynamic>;

sealed class TimelineEntry {
  const TimelineEntry({required this.id, this.created});

  final String id;

  /// Epoch milliseconds.
  final double? created;

  /// Returns null for record types this client does not display.
  /// Throws [FormatException] for a record without `id` or `type`.
  static TimelineEntry? tryParse(Json json) {
    final id = json['id'];
    final type = json['type'];
    if (id is! String || type is! String) {
      throw FormatException('Timeline record without id/type', json);
    }
    final created = _num(_obj(json['time'])?['created']);
    switch (type) {
      case 'user':
        return UserEntry(
          id: id,
          created: created,
          text: json['text'] as String? ?? '',
          files: [
            for (final f in _list(json['files']))
              if (f is Map)
                AttachedFile(
                  name: f['name'] as String?,
                  mime: f['mime'] as String?,
                  base64Data: f['data'] as String?,
                ),
          ],
          agents: [
            for (final a in _list(json['agents']))
              if (a is Map && a['name'] is String) a['name'] as String,
          ],
        );
      case 'assistant':
        final time = _obj(json['time']);
        return AssistantEntry(
          id: id,
          created: created,
          completed: _num(time?['completed']),
          agent: json['agent'] as String?,
          model: _obj(json['model']) == null
              ? null
              : ModelRef.fromJson(_obj(json['model'])!),
          finish: json['finish'] as String?,
          errorMessage: _obj(json['error'])?['message'] as String?,
          cost: _num(json['cost']),
          content: [
            for (final c in _list(json['content']))
              if (c is Map)
                ?AssistantContent.tryParse(c.cast<String, dynamic>()),
          ],
        );
      case 'compaction':
        return CompactionEntry(
          id: id,
          created: created,
          summary: [
            json['summary'],
            json['recent'],
          ].whereType<String>().where((s) => s.isNotEmpty).join('\n\n'),
        );
      case 'shell':
        return ShellEntry(
          id: id,
          created: created,
          command: json['command'] as String? ?? '',
          status: json['status'] as String?,
          exitCode: _num(json['exit'])?.toInt(),
          output: _obj(json['output'])?['output'] as String?,
        );
      case 'synthetic' ||
          'system' ||
          'skill' ||
          'agent-switched' ||
          'model-switched' ||
          'location-switched':
        final text =
            json['text'] as String? ??
            json['description'] as String? ??
            json['name'] as String? ??
            json['agent'] as String? ??
            _obj(json['model'])?['id'] as String? ??
            _obj(json['location'])?['directory'] as String?;
        if (text == null) return null;
        return ContextEntry(id: id, created: created, kind: type, text: text);
      default:
        return null;
    }
  }
}

class AttachedFile {
  const AttachedFile({this.name, this.mime, this.base64Data});

  final String? name;
  final String? mime;
  final String? base64Data;
}

class UserEntry extends TimelineEntry {
  const UserEntry({
    required super.id,
    super.created,
    required this.text,
    this.files = const [],
    this.agents = const [],
  });

  final String text;
  final List<AttachedFile> files;
  final List<String> agents;
}

class AssistantEntry extends TimelineEntry {
  const AssistantEntry({
    required super.id,
    super.created,
    this.completed,
    this.agent,
    this.model,
    this.finish,
    this.errorMessage,
    this.cost,
    this.content = const [],
  });

  final double? completed;
  final String? agent;
  final ModelRef? model;
  final String? finish;
  final String? errorMessage;
  final double? cost;
  final List<AssistantContent> content;
}

/// A summary that replaced older history when the session was compacted.
class CompactionEntry extends TimelineEntry {
  const CompactionEntry({
    required super.id,
    super.created,
    required this.summary,
  });

  final String summary;
}

/// A shell command the user ran directly in the session.
class ShellEntry extends TimelineEntry {
  const ShellEntry({
    required super.id,
    super.created,
    required this.command,
    this.status,
    this.exitCode,
    this.output,
  });

  final String command;
  final String? status;
  final int? exitCode;
  final String? output;

  bool get isRunning => status == 'running';
  bool get succeeded => status == 'exited' && exitCode == 0;
}

/// Context the server injected (system notes, skill loads, agent/model or
/// location switches). Shown as a small caption rather than a message.
class ContextEntry extends TimelineEntry {
  const ContextEntry({
    required super.id,
    super.created,
    required this.kind,
    required this.text,
  });

  final String kind;
  final String text;
}

sealed class AssistantContent {
  const AssistantContent();

  static AssistantContent? tryParse(Json json) {
    switch (json['type']) {
      case 'text':
        return TextContent(json['text'] as String? ?? '');
      case 'reasoning':
        return ReasoningContent(json['text'] as String? ?? '');
      case 'tool':
        final id = json['id'];
        if (id is! String) return null;
        final state = _obj(json['state']) ?? const {};
        final output = [
          for (final item in _list(state['content']))
            if (item is Map && item['type'] == 'text')
              item['text']
            else if (item is Map && item['type'] == 'file')
              item['name'] ?? item['uri'],
        ].whereType<String>().join('\n');
        return ToolContent(
          id: id,
          name: json['name'] as String? ?? 'tool',
          status: ToolStatus.parse(state['status'] as String?),
          input: _obj(state['input']) ?? const {},
          output: output.isEmpty ? null : output,
          errorMessage: _obj(state['error'])?['message'] as String?,
        );
      default:
        return null;
    }
  }
}

class TextContent extends AssistantContent {
  const TextContent(this.text);
  final String text;
}

class ReasoningContent extends AssistantContent {
  const ReasoningContent(this.text);
  final String text;
}

enum ToolStatus {
  pending,
  running,
  completed,
  error;

  static ToolStatus parse(String? value) => switch (value) {
    'running' => running,
    'completed' => completed,
    'error' => error,
    _ => pending, // includes `streaming` (input still arriving)
  };
}

class ToolContent extends AssistantContent {
  const ToolContent({
    required this.id,
    required this.name,
    required this.status,
    this.input = const {},
    this.output,
    this.errorMessage,
  });

  final String id;
  final String name;
  final ToolStatus status;
  final Json input;
  final String? output;
  final String? errorMessage;

  /// A one-line description of what the tool acted on.
  String? get subject {
    for (final key in const [
      'description',
      'command',
      'filePath',
      'path',
      'pattern',
      'query',
      'url',
    ]) {
      final value = input[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}

Json? _obj(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;

List<Object?> _list(Object? value) => value is List ? value : const [];

double? _num(Object? value) => value is num ? value.toDouble() : null;
