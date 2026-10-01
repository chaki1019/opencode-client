import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/events/server_event.dart';
import 'package:opencode_mobile/core/models/timeline.dart';
import 'package:opencode_mobile/core/sync/live_timeline.dart';

const session = 's1';

ServerEvent ev(String type, Map<String, dynamic> data, {double? at}) =>
    ServerEvent(type: type, created: at, data: {'sessionID': session, ...data});

ServerEvent step(String type, {double? at, Map<String, dynamic>? extra}) =>
    ev(type, {'assistantMessageID': 'a1', ...?extra}, at: at);

ServerEvent part(String type, int ordinal, [Map<String, dynamic>? extra]) =>
    ev(type, {'assistantMessageID': 'a1', 'ordinal': ordinal, ...?extra});

/// Applies events in order, failing if one asks for a resync.
List<TimelineEntry> run(
  LiveTimeline live,
  List<ServerEvent> events, [
  List<TimelineEntry> start = const [],
]) {
  var entries = start;
  for (final event in events) {
    final update = live.apply(entries, event);
    if (update is NeedsResync) fail('unexpected resync for ${event.type}');
    if (update is Changed) entries = update.entries;
  }
  return entries;
}

AssistantEntry assistant(List<TimelineEntry> entries) =>
    entries.whereType<AssistantEntry>().single;

void main() {
  test('streams text from started through deltas to ended', () {
    final live = LiveTimeline(session);
    var entries = run(live, [
      step('session.step.started', at: 10),
      part('session.text.started', 0),
      part('session.text.delta', 0, {'delta': 'Hel'}),
      part('session.text.delta', 0, {'delta': 'lo'}),
    ]);
    expect(assistant(entries).isStreaming, isTrue);
    expect((assistant(entries).content.single as TextContent).text, 'Hello');

    entries = run(live, [
      part('session.text.ended', 0, {'text': 'Hello!'}),
      part('session.text.delta', 0, {'delta': ' late'}),
      step(
        'session.step.ended',
        at: 20,
        extra: {
          'finish': 'stop',
          'model': {'providerID': 'p', 'id': 'm'},
        },
      ),
    ], entries);
    final done = assistant(entries);
    expect((done.content.single as TextContent).text, 'Hello!');
    expect(done.completed, 20);
    expect(done.finish, 'stop');
    expect(done.model?.id, 'm');
  });

  test('ignores a delta that arrives before its part was started', () {
    final live = LiveTimeline(session);
    final entries = run(live, [
      step('session.step.started'),
      part('session.reasoning.delta', 0, {'delta': 'x'}),
    ]);
    expect(assistant(entries).content, isEmpty);
  });

  test('addresses text and reasoning ordinals independently', () {
    final live = LiveTimeline(session);
    final entries = run(live, [
      step('session.step.started'),
      part('session.reasoning.started', 0),
      part('session.text.started', 0),
      part('session.reasoning.started', 1),
      part('session.reasoning.delta', 1, {'delta': 'second'}),
      part('session.text.delta', 0, {'delta': 'answer'}),
    ]);
    final content = assistant(entries).content;
    expect(content.map((c) => c.runtimeType), [
      ReasoningContent,
      TextContent,
      ReasoningContent,
    ]);
    expect((content[1] as TextContent).text, 'answer');
    expect((content[2] as ReasoningContent).text, 'second');
  });

  test('tracks a tool call from input to result', () {
    final live = LiveTimeline(session);
    var entries = run(live, [
      step('session.step.started'),
      ev('session.tool.input.started', {
        'assistantMessageID': 'a1',
        'id': 't1',
        'name': 'bash',
      }),
    ]);
    expect(
      (assistant(entries).content.single as ToolContent).status,
      ToolStatus.pending,
    );

    entries = run(live, [
      ev('session.tool.called', {
        'assistantMessageID': 'a1',
        'id': 't1',
        'input': {'command': 'ls'},
      }),
    ], entries);
    var tool = assistant(entries).content.single as ToolContent;
    expect(tool.status, ToolStatus.running);
    expect(tool.subject, 'ls');

    entries = run(live, [
      ev('session.tool.success', {
        'assistantMessageID': 'a1',
        'id': 't1',
        'content': [
          {'type': 'text', 'text': 'file.txt'},
        ],
      }),
    ], entries);
    tool = assistant(entries).content.single as ToolContent;
    expect(tool.status, ToolStatus.completed);
    expect(tool.output, 'file.txt');
  });

  test('a failed tool keeps its error message', () {
    final live = LiveTimeline(session);
    final entries = run(live, [
      step('session.step.started'),
      ev('session.tool.input.started', {
        'assistantMessageID': 'a1',
        'id': 't1',
        'name': 'read',
      }),
      ev('session.tool.failed', {
        'assistantMessageID': 'a1',
        'id': 't1',
        'error': {'message': 'not found'},
      }),
    ]);
    final tool = assistant(entries).content.single as ToolContent;
    expect(tool.status, ToolStatus.error);
    expect(tool.errorMessage, 'not found');
  });

  test('shows an admitted prompt once it is promoted', () {
    final live = LiveTimeline(session);
    var entries = run(live, [
      ev('session.input.admitted', {
        'inputID': 'u1',
        'input': {
          'type': 'user',
          'data': {'text': 'Fix it'},
        },
      }),
    ]);
    expect(entries, isEmpty);
    entries = run(live, [
      ev('session.input.promoted', {'inputID': 'u1'}),
    ], entries);
    expect((entries.single as UserEntry).text, 'Fix it');
  });

  test('asks for a resync when a promoted input was never seen', () {
    final live = LiveTimeline(session);
    expect(
      live.apply(const [], ev('session.input.promoted', {'inputID': 'u9'})),
      isA<NeedsResync>(),
    );
  });

  test('revert removes the boundary message and everything after it', () {
    final live = LiveTimeline(session);
    final entries = run(
      live,
      [
        ev('session.revert.committed', {'to': 'u2'}),
      ],
      const [
        UserEntry(id: 'u1', text: 'a'),
        UserEntry(id: 'u2', text: 'b'),
        AssistantEntry(id: 'a2', completed: 1),
      ],
    );
    expect(entries.map((e) => e.id), ['u1']);
  });

  test('a replayed older step does not reopen a finished message', () {
    final live = LiveTimeline(session);
    final entries = run(live, [
      step('session.step.started', at: 10),
      step('session.step.ended', at: 20),
      step('session.step.started', at: 15),
    ]);
    expect(assistant(entries).completed, 20);
  });

  test(
    'ignores other sessions and resyncs on unmodelled transcript events',
    () {
      final live = LiveTimeline(session);
      expect(
        live.apply(
          const [],
          const ServerEvent(
            type: 'session.step.started',
            data: {'sessionID': 'other', 'assistantMessageID': 'x'},
          ),
        ),
        isA<Unchanged>(),
      );
      expect(
        live.apply(const [], ev('session.shell.started', {})),
        isA<NeedsResync>(),
      );
    },
  );
}
