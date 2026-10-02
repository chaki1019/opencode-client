import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/agent_labels.dart';

void main() {
  test('capitalizes agent ids', () {
    expect(agentDisplayName('build'), 'Build');
    expect(agentDisplayName('plan'), 'Plan');
    expect(agentDisplayName(''), '');
  });

  test('built-in agents use the documented description', () {
    expect(agentDescription('build', 'server text'), isNot('server text'));
    expect(agentDescription('custom', 'server text'), 'server text');
    expect(agentDescription('custom', null), isNull);
  });
}
