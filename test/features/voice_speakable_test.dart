import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/timeline.dart';
import 'package:opencode_mobile/features/voice/speakable.dart';

String speak(String markdown) =>
    speakableText(markdown, codeSkipped: '(code)', truncated: '(more)');

void main() {
  test('markdown symbols are dropped and code is skipped', () {
    expect(
      speak(
        '# Done\n\n'
        'I **fixed** the `login` bug in [auth](https://x.test).\n\n'
        '- one\n- two\n\n'
        '```dart\nvoid main() {}\n```\n'
        '> quoted',
      ),
      'Done\n\nI fixed the login bug in auth.\n\none\ntwo\n\n(code)\n\nquoted',
    );
  });

  test('identifiers keep their underscores', () {
    expect(
      speak('Set MAX_RETRIES and snake_case'),
      'Set MAX_RETRIES and snake_case',
    );
  });

  test('long text is cut', () {
    final text = speak('a' * (maxSpokenLength + 10));
    expect(text, '${'a' * maxSpokenLength}\n(more)');
  });

  test('the reply is the assistant text after the last user message', () {
    final entries = <TimelineEntry>[
      const AssistantEntry(id: 'a0', content: [TextContent('old')]),
      const UserEntry(id: 'u1', text: 'go'),
      const AssistantEntry(
        id: 'a1',
        content: [ReasoningContent('hmm'), TextContent('First.')],
      ),
      const AssistantEntry(id: 'a2', content: [TextContent('Second.')]),
    ];
    expect(latestReplyText(entries), 'First.\n\nSecond.');
  });
}
