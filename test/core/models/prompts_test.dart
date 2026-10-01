import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/prompts.dart';

void main() {
  test('parses a permission request and its tool source', () {
    final request = PermissionRequest.tryParse({
      'id': 'per_1',
      'sessionID': 'ses_1',
      'action': 'bash',
      'resources': ['git status*'],
      'save': ['git status*'],
      'metadata': {'command': 'git status --short'},
      'source': {'type': 'tool', 'messageID': 'msg_1', 'id': 'call_1'},
    })!;
    expect(request.action, 'bash');
    expect(request.resources, ['git status*']);
    expect(request.save, ['git status*']);
    expect(request.description, 'git status --short');
    expect(request.messageId, 'msg_1');
    expect(request.callId, 'call_1');
    expect(PermissionRequest.tryParse({'id': 'x'}), isNull);
  });

  test('prefers the request message as its description', () {
    final request = PermissionRequest.tryParse({
      'id': 'p',
      'sessionID': 's',
      'action': 'edit',
      'resources': ['*'],
      'message': 'Edit main.dart',
      'metadata': {'filePath': '/a/main.dart'},
    })!;
    expect(request.description, 'Edit main.dart');
  });

  test('reads todos from a todo tool input', () {
    final todos = TodoItem.fromToolInput({
      'todos': [
        {'content': 'Write tests', 'status': 'completed', 'priority': 'high'},
        {'content': 'Ship', 'status': 'in_progress'},
        {'status': 'pending'},
      ],
    })!;
    expect(todos.map((t) => t.content), ['Write tests', 'Ship']);
    expect(todos.first.isDone, isTrue);
    expect(todos.last.isActive, isTrue);
    expect(TodoItem.fromToolInput({}), isNull);
    expect(TodoItem.isTodoTool('todowrite'), isTrue);
    expect(TodoItem.isTodoTool('bash'), isFalse);
  });
}
