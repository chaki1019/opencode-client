import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/timeline.dart';

void main() {
  test('parses a user record with files and agent mentions', () {
    final entry = TimelineEntry.tryParse({
      'id': 'u1',
      'type': 'user',
      'text': 'hello @build',
      'time': {'created': 1000},
      'files': [
        {'name': 'a.png', 'mime': 'image/png', 'data': 'AAAA'},
      ],
      'agents': [
        {
          'name': 'build',
          'mention': {'start': 6, 'end': 12, 'text': '@build'},
        },
      ],
    });
    expect(entry, isA<UserEntry>());
    final user = entry! as UserEntry;
    expect(user.text, 'hello @build');
    expect(user.created, 1000);
    expect(user.files.single.name, 'a.png');
    expect(user.agents, ['build']);
  });

  test('parses assistant content in order', () {
    final entry =
        TimelineEntry.tryParse({
              'id': 'a1',
              'type': 'assistant',
              'agent': 'build',
              'model': {
                'providerID': 'anthropic',
                'id': 'claude',
                'variant': 'high',
              },
              'time': {'created': 1, 'completed': 2},
              'content': [
                {'type': 'reasoning', 'text': 'thinking'},
                {
                  'type': 'tool',
                  'id': 't1',
                  'name': 'bash',
                  'state': {
                    'status': 'completed',
                    'input': {'command': 'ls', 'description': 'List files'},
                    'content': [
                      {'type': 'text', 'text': 'a\nb'},
                      {'type': 'file', 'name': 'out.txt'},
                    ],
                  },
                },
                {'type': 'text', 'text': 'Done.'},
                {'type': 'future-thing'},
              ],
            })!
            as AssistantEntry;

    expect(entry.model?.label, 'claude (high)');
    expect(entry.completed, 2);
    expect(entry.content, hasLength(3));
    expect((entry.content[0] as ReasoningContent).text, 'thinking');
    final tool = entry.content[1] as ToolContent;
    expect(tool.status, ToolStatus.completed);
    expect(tool.subject, 'List files');
    expect(tool.output, 'a\nb\nout.txt');
    expect((entry.content[2] as TextContent).text, 'Done.');
  });

  test('maps streaming tool status to pending and reads errors', () {
    final entry =
        TimelineEntry.tryParse({
              'id': 'a2',
              'type': 'assistant',
              'error': {'type': 'APIError', 'message': 'rate limited'},
              'content': [
                {
                  'type': 'tool',
                  'id': 't',
                  'name': 'read',
                  'state': {'status': 'streaming'},
                },
              ],
            })!
            as AssistantEntry;
    expect((entry.content.single as ToolContent).status, ToolStatus.pending);
    expect(entry.errorMessage, 'rate limited');
  });

  test('parses compaction, shell and context records', () {
    final compaction =
        TimelineEntry.tryParse({
              'id': 'c',
              'type': 'compaction',
              'summary': 'S',
              'recent': 'R',
            })!
            as CompactionEntry;
    expect(compaction.summary, 'S\n\nR');
    expect(compaction.running, isFalse);
    final running =
        TimelineEntry.tryParse({
              'id': 'c2',
              'type': 'compaction',
              'status': 'running',
              'summary': '',
              'recent': '',
            })!
            as CompactionEntry;
    expect(running.running, isTrue);

    final shell =
        TimelineEntry.tryParse({
              'id': 's',
              'type': 'shell',
              'command': 'make',
              'status': 'exited',
              'exit': 0,
              'output': {'output': 'ok'},
            })!
            as ShellEntry;
    expect(shell.succeeded, isTrue);
    expect(shell.output, 'ok');

    final switched =
        TimelineEntry.tryParse({
              'id': 'm',
              'type': 'model-switched',
              'model': {'providerID': 'p', 'id': 'gpt'},
            })!
            as ContextEntry;
    expect(switched.kind, 'model-switched');
    expect(switched.text, 'gpt');
  });

  test('skips unknown record types and rejects records without a type', () {
    expect(TimelineEntry.tryParse({'id': 'x', 'type': 'step-marker'}), isNull);
    expect(
      () => TimelineEntry.tryParse({'id': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });
}
