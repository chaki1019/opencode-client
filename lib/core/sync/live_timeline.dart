import '../events/server_event.dart';
import '../models/session.dart';
import '../models/timeline.dart';

/// Result of applying one event to a timeline.
sealed class TimelineUpdate {
  const TimelineUpdate();
}

/// The event did not change what is shown.
class Unchanged extends TimelineUpdate {
  const Unchanged();
}

class Changed extends TimelineUpdate {
  const Changed(this.entries);
  final List<TimelineEntry> entries;
}

/// The event changes the transcript in a way this reducer does not model
/// (shell runs, compaction, context records...). The caller should refetch
/// the newest page.
class NeedsResync extends TimelineUpdate {
  const NeedsResync();
}

/// Applies v2 session events to one session's timeline.
///
/// Streaming text arrives as `session.text.started` / `.delta` / `.ended`
/// (likewise for reasoning). Parts are addressed by `ordinal`, counted per
/// type within the assistant message, so the n-th text part is the n-th
/// [TextContent] regardless of reasoning or tool parts between them.
///
/// Deltas only extend a part that was announced with `started` and has not
/// `ended`; `ended` carries the full text and is authoritative.
class LiveTimeline {
  LiveTimeline(this.sessionId);

  final String sessionId;
  final Set<String> _endedParts = {};
  final Map<String, TimelineEntry> _admittedInputs = {};

  TimelineUpdate apply(List<TimelineEntry> entries, ServerEvent event) {
    if (event.sessionId != sessionId) return const Unchanged();
    final data = event.data;
    final messageId = event.assistantMessageId;

    switch (event.type) {
      case 'session.input.admitted' || 'session.inbox.enqueued':
        final id =
            data[event.type == 'session.input.admitted'
                ? 'inputID'
                : 'inboxID'];
        final input = _admittedInput(event);
        if (id is String && input != null) {
          _admittedInputs[id] = _inputEntry(id, input, event.created);
        }
        return const Unchanged();

      case 'session.input.promoted' || 'session.inbox.delivered':
        final id =
            data[event.type == 'session.input.promoted'
                ? 'inputID'
                : 'inboxID'];
        if (id is! String) return const Unchanged();
        final entry = _admittedInputs.remove(id);
        if (entry == null) return const NeedsResync();
        final index = entries.indexWhere((e) => e.id == id);
        return Changed(
          index < 0 ? [...entries, entry] : ([...entries]..[index] = entry),
        );

      case 'session.input.cancelled' || 'session.inbox.cancelled':
        final id =
            data[event.type == 'session.input.cancelled'
                ? 'inputID'
                : 'inboxID'];
        if (id is! String) return const Unchanged();
        _admittedInputs.remove(id);
        if (!entries.any((e) => e.id == id)) return const Unchanged();
        return Changed(entries.where((e) => e.id != id).toList());

      case 'session.step.started':
        if (messageId == null) return const Unchanged();
        final existing = _assistant(entries, messageId);
        final completed = existing?.completed;
        if (completed != null &&
            event.created != null &&
            event.created! <= completed) {
          return const Unchanged(); // replay of an older step
        }
        var next = entries;
        // A new step supersedes an unfinished earlier one.
        if (existing == null) {
          final last = _lastStreamingAssistant(next);
          if (last != null) {
            next = _replace(
              next,
              last.copyWith(completed: () => event.created),
            );
          }
        }
        _endedParts.removeWhere((k) => k.startsWith('$messageId:'));
        final (list, entry) = _ensureAssistant(next, messageId, event);
        return Changed(
          _replace(
            list,
            entry.copyWith(
              completed: () => null,
              finish: () => null,
              errorMessage: () => null,
              agent: data['agent'] as String?,
              model: _model(data['model']),
            ),
          ),
        );

      case 'session.step.ended' || 'session.step.failed':
        if (messageId == null) return const Unchanged();
        final (list, entry) = _ensureAssistant(entries, messageId, event);
        final error = data['error'];
        final errorMessage = error is Map ? error['message'] as String? : null;
        final cost = data['cost'];
        return Changed(
          _replace(
            list,
            entry.copyWith(
              completed: () => event.created ?? entry.created ?? 0,
              finish: () =>
                  data['finish'] as String? ??
                  (errorMessage != null ? 'error' : entry.finish),
              errorMessage: () => errorMessage ?? entry.errorMessage,
              agent: data['agent'] as String?,
              model: _model(data['model']),
              cost: cost is num ? cost.toDouble() : null,
            ),
          ),
        );

      case 'session.text.started' || 'session.reasoning.started':
        final ordinal = data['ordinal'];
        if (messageId == null || ordinal is! int || ordinal < 0) {
          return const Unchanged();
        }
        final isText = event.type == 'session.text.started';
        final (list, entry) = _ensureAssistant(entries, messageId, event);
        if (_ordinalIndex(entry.content, isText, ordinal) >= 0) {
          return const Unchanged();
        }
        return Changed(
          _replace(
            list,
            entry.copyWith(
              content: [
                ...entry.content,
                isText ? const TextContent('') : const ReasoningContent(''),
              ],
            ),
          ),
        );

      case 'session.text.delta' || 'session.reasoning.delta':
        final ordinal = data['ordinal'];
        final delta = data['delta'];
        if (messageId == null || ordinal is! int || delta is! String) {
          return const Unchanged();
        }
        final isText = event.type == 'session.text.delta';
        if (_endedParts.contains(_partKey(messageId, isText, ordinal))) {
          return const Unchanged();
        }
        final entry = _assistant(entries, messageId);
        if (entry == null || !entry.isStreaming) return const Unchanged();
        final index = _ordinalIndex(entry.content, isText, ordinal);
        if (index < 0) return const Unchanged(); // delta before `started`
        final previous = _textOf(entry.content[index]);
        return Changed(
          _replace(
            entries,
            entry.copyWith(
              content: [...entry.content]
                ..[index] = _textContent(isText, previous + delta),
            ),
          ),
        );

      case 'session.text.ended' || 'session.reasoning.ended':
        final ordinal = data['ordinal'];
        final text = data['text'];
        if (messageId == null || ordinal is! int || text is! String) {
          return const Unchanged();
        }
        final isText = event.type == 'session.text.ended';
        _endedParts.add(_partKey(messageId, isText, ordinal));
        final (list, entry) = _ensureAssistant(entries, messageId, event);
        final index = _ordinalIndex(entry.content, isText, ordinal);
        final content = [...entry.content];
        if (index < 0) {
          content.add(_textContent(isText, text));
        } else {
          content[index] = _textContent(isText, text);
        }
        return Changed(_replace(list, entry.copyWith(content: content)));

      case 'session.tool.input.started':
        final toolId = data['id'];
        final name = data['name'];
        if (messageId == null || toolId is! String || name is! String) {
          return const Unchanged();
        }
        final (list, entry) = _ensureAssistant(entries, messageId, event);
        if (_toolIndex(entry.content, toolId) >= 0) return const Unchanged();
        return Changed(
          _replace(
            list,
            entry.copyWith(
              content: [
                ...entry.content,
                ToolContent(id: toolId, name: name, status: ToolStatus.pending),
              ],
            ),
          ),
        );

      case 'session.tool.called':
        return _updateTool(entries, messageId, data, (tool) {
          if (tool.status != ToolStatus.pending) return null;
          final input = data['input'];
          return tool.copyWith(
            status: ToolStatus.running,
            input: input is Map ? input.cast<String, dynamic>() : null,
          );
        });

      case 'session.tool.success' || 'session.tool.failed':
        final failed = event.type == 'session.tool.failed';
        return _updateTool(entries, messageId, data, (tool) {
          final allowed =
              tool.status == ToolStatus.running ||
              (failed && tool.status == ToolStatus.pending);
          if (!allowed) return null;
          final error = data['error'];
          return tool.copyWith(
            status: failed ? ToolStatus.error : ToolStatus.completed,
            output: toolOutputText(data['content']),
            errorMessage: failed && error is Map
                ? error['message'] as String?
                : null,
          );
        });

      case 'session.message.content.updated':
        final id = data['messageID'];
        final content = data['content'];
        if (id is! String || content is! List) return const Unchanged();
        final (list, entry) = _ensureAssistant(entries, id, event);
        return Changed(
          _replace(
            list,
            entry.copyWith(
              content: [
                for (final item in content)
                  if (item is Map)
                    ?AssistantContent.tryParse(item.cast<String, dynamic>()),
              ],
            ),
          ),
        );

      case 'session.revert.committed':
        final boundary = data['to'];
        final index = entries.indexWhere((e) => e.id == boundary);
        if (index < 0) return const Unchanged();
        return Changed(entries.sublist(0, index));

      case 'session.tool.input.delta' ||
          'session.tool.input.ended' ||
          'session.tool.progress' ||
          'session.step.streamed':
        return const Unchanged();
    }

    if (_affectsTranscript(event.type)) return const NeedsResync();
    return const Unchanged();
  }

  static bool _affectsTranscript(String type) =>
      type.startsWith('session.shell.') ||
      type.startsWith('session.compaction.') ||
      const {
        'session.synthetic',
        'session.instructions.updated',
        'session.skill.activated',
        'session.agent.selected',
        'session.model.selected',
        'session.moved',
      }.contains(type);

  TimelineUpdate _updateTool(
    List<TimelineEntry> entries,
    String? messageId,
    Map<String, dynamic> data,
    ToolContent? Function(ToolContent tool) update,
  ) {
    final toolId = data['id'];
    if (messageId == null || toolId is! String) return const Unchanged();
    final entry = _assistant(entries, messageId);
    if (entry == null) return const Unchanged();
    final index = _toolIndex(entry.content, toolId);
    if (index < 0) return const Unchanged();
    final updated = update(entry.content[index] as ToolContent);
    if (updated == null) return const Unchanged();
    return Changed(
      _replace(
        entries,
        entry.copyWith(content: [...entry.content]..[index] = updated),
      ),
    );
  }

  static String _partKey(String messageId, bool isText, int ordinal) =>
      '$messageId:${isText ? 'text' : 'reasoning'}:$ordinal';

  static int _ordinalIndex(
    List<AssistantContent> content,
    bool isText,
    int ordinal,
  ) {
    var seen = 0;
    for (var i = 0; i < content.length; i++) {
      final matches = isText
          ? content[i] is TextContent
          : content[i] is ReasoningContent;
      if (!matches) continue;
      if (seen == ordinal) return i;
      seen++;
    }
    return -1;
  }

  static int _toolIndex(List<AssistantContent> content, String toolId) =>
      content.indexWhere((c) => c is ToolContent && c.id == toolId);

  static String _textOf(AssistantContent content) => switch (content) {
    TextContent(:final text) => text,
    ReasoningContent(:final text) => text,
    _ => '',
  };

  static AssistantContent _textContent(bool isText, String text) =>
      isText ? TextContent(text) : ReasoningContent(text);

  static AssistantEntry? _assistant(List<TimelineEntry> entries, String id) {
    for (final e in entries) {
      if (e.id == id) return e is AssistantEntry ? e : null;
    }
    return null;
  }

  static AssistantEntry? _lastStreamingAssistant(List<TimelineEntry> entries) {
    for (final e in entries.reversed) {
      if (e is AssistantEntry) return e.isStreaming ? e : null;
    }
    return null;
  }

  static (List<TimelineEntry>, AssistantEntry) _ensureAssistant(
    List<TimelineEntry> entries,
    String id,
    ServerEvent event,
  ) {
    final existing = _assistant(entries, id);
    if (existing != null) return (entries, existing);
    final created = AssistantEntry(id: id, created: event.created);
    return ([...entries, created], created);
  }

  static List<TimelineEntry> _replace(
    List<TimelineEntry> entries,
    TimelineEntry entry,
  ) {
    final index = entries.indexWhere((e) => e.id == entry.id);
    return index < 0 ? [...entries, entry] : ([...entries]..[index] = entry);
  }

  static ModelRef? _model(Object? value) {
    if (value is! Map ||
        value['providerID'] is! String ||
        value['id'] is! String) {
      return null;
    }
    return ModelRef.fromJson(value.cast<String, dynamic>());
  }

  /// `input.admitted` carries `{input: {type, data}}`; `inbox.enqueued`
  /// carries `{item: {type, payload}}`.
  static (String, Map<String, dynamic>)? _admittedInput(ServerEvent event) {
    final container = event.type == 'session.input.admitted'
        ? event.data['input']
        : event.data['item'];
    if (container is! Map) return null;
    final type = container['type'];
    final payload =
        container[event.type == 'session.input.admitted' ? 'data' : 'payload'];
    if (type is! String || payload is! Map) return null;
    return (type, payload.cast<String, dynamic>());
  }

  static TimelineEntry _inputEntry(
    String id,
    (String, Map<String, dynamic>) input,
    double? created,
  ) {
    final (type, payload) = input;
    final text = payload['text'] as String? ?? '';
    if (type == 'synthetic') {
      return ContextEntry(
        id: id,
        created: created,
        kind: 'synthetic',
        text: text,
      );
    }
    return TimelineEntry.tryParse({
          ...payload,
          'id': id,
          'type': 'user',
          'time': {'created': ?created},
        }) ??
        UserEntry(id: id, created: created, text: text);
  }
}
