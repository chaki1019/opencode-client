import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/models/attachment.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/chat/composer_providers.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/main.dart';

import 'support/fake_adapter.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    // Most checks below read the Japanese strings.
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localeTestValue = const Locale(
      'ja',
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue(),
  );

  testWidgets('the connect screen follows the device language', (tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    await tester.pumpWidget(const ProviderScope(child: OpenCodeMobileApp()));
    await tester.pumpAndSettle();
    expect(find.text('Connect to an OpenCode server'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
    await tester.pumpAndSettle();
    expect(find.text('OpenCode サーバーに接続'), findsOneWidget);
  });

  testWidgets('connecting shows the project list and saves the server', (
    tester,
  ) async {
    // The checks below read the Japanese strings.
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    final promptIds = <String>[];
    final promptBodies = <Map<String, dynamic>>[];
    final replies = <RequestOptions>[];
    final adapter = FakeAdapter({
      '/api/health': FakeRoute.json({
        'healthy': true,
        'version': '2.0.0',
        'pid': 1,
      }),
      '/api/location': FakeRoute.json({
        'directory': '/home/me/my-app',
        'project': {'id': 'abc', 'directory': '/home/me/my-app'},
      }),
      '/api/project': FakeRoute.json([
        {'id': 'abc', 'canonical': '/home/me/my-app', 'sandboxes': []},
      ]),
      '/api/session': FakeRoute.json({
        'data': [
          {
            'id': 's1',
            'projectID': 'abc',
            'title': 'Fix the login bug',
            'location': {'directory': '/home/me/my-app'},
            'time': {'created': 1, 'updated': 2},
          },
        ],
      }),
      '/api/session/active': FakeRoute.json({'data': {}}),
      '/api/session/s1/permission': FakeRoute.json({
        'data': [
          {
            'id': 'per_1',
            'sessionID': 's1',
            'action': 'bash',
            'resources': ['git push*'],
            'metadata': {'command': 'git push'},
          },
        ],
      }),
      '/api/session/s1/permission/per_1/reply': (RequestOptions request) {
        replies.add(request);
        return const FakeRoute(204, '');
      },
      '/api/session/s1/form': FakeRoute.json({'data': []}),
      '/api/session/s1/form/frm_1/reply': (RequestOptions request) {
        replies.add(request);
        return const FakeRoute(204, '');
      },
      '/api/vcs': FakeRoute.json({
        'data': {
          'branch': {'current': 'fix-login', 'default': 'main'},
        },
      }),
      '/api/vcs/diff': FakeRoute.json({
        'data': [
          {
            'file': 'lib/login.dart',
            'patch': '@@ -1 +1 @@\n-old\n+new',
            'additions': 1,
            'deletions': 1,
            'status': 'modified',
          },
        ],
      }),
      '/api/vcs/status': FakeRoute.json({'data': []}),
      '/api/fs/list': FakeRoute.json({
        'data': [
          {'path': 'lib/', 'type': 'directory'},
          {'path': 'README.md', 'type': 'file'},
        ],
      }),
      '/api/fs/read/README.md': const FakeRoute(
        200,
        '# My app',
        contentType: 'text/markdown',
      ),
      '/api/mcp': FakeRoute.json({
        'data': [
          {
            'name': 'github',
            'status': {'status': 'connected'},
          },
        ],
      }),
      '/api/mcp/github/disconnect': (RequestOptions request) {
        replies.add(request);
        return const FakeRoute(204, '');
      },
      '/api/session/s1': (RequestOptions request) {
        replies.add(request);
        return request.method == 'GET'
            ? FakeRoute.json({
                'data': {
                  'id': 's1',
                  'projectID': 'abc',
                  'title': 'Login fixed',
                  'location': {'directory': '/home/me/my-app'},
                  'time': {'created': 1, 'updated': 3},
                },
              })
            : const FakeRoute(204, '');
      },
      '/api/session/s1/prompt': (RequestOptions request) {
        final body = jsonDecode(request.data as String) as Map<String, dynamic>;
        promptIds.add(body['id'] as String);
        promptBodies.add(body);
        return FakeRoute.json({
          'data': {'id': body['id'], 'sessionID': 's1', 'delivery': 'queued'},
        });
      },
      '/api/session/s1/message': FakeRoute.json({
        'data': [
          {
            'id': 'a1',
            'type': 'assistant',
            'content': [
              {'type': 'text', 'text': 'The bug is **fixed**.'},
              {
                'type': 'tool',
                'id': 'call_todo',
                'name': 'todowrite',
                'state': {
                  'status': 'completed',
                  'input': {
                    'todos': [
                      {'content': 'Reproduce', 'status': 'completed'},
                      {'content': 'Fix login', 'status': 'in_progress'},
                    ],
                  },
                  'content': [],
                },
              },
            ],
          },
          {'id': 'u1', 'type': 'user', 'text': 'Please fix login'},
        ],
      }),
    });
    final store = ServerStore();
    final events = StreamController<List<int>>();
    void send(String type, Map<String, Object?> data) => events.add(
      utf8.encode(
        'data: ${jsonEncode({
          'type': type,
          'data': {'sessionID': 's1', ...data},
        })}\n\n',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverStoreProvider.overrideWithValue(store),
          pickImagesProvider.overrideWithValue(
            ({bool camera = false}) async => [
              PromptFile(
                name: 'shot.png',
                mime: 'image/png',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
            ],
          ),
          eventStreamProvider.overrideWith((ref) {
            if (ref.watch(connectionProvider) == null) return null;
            final stream = EventStream(open: (_) async => events.stream)
              ..start();
            ref.onDispose(stream.dispose);
            return stream;
          }),
          clientFactoryProvider.overrideWithValue(
            (server, password) => OpenCodeClient(
              baseUrl: server.baseUrl,
              username: server.username,
              password: password,
              dio: fakeDio(adapter),
            ),
          ),
        ],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('url')), 'example.test:4096');
    await tester.enterText(find.byKey(const Key('password')), 'pw');
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pumpAndSettle();

    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('OpenCode 2.0.0'), findsOneWidget);

    await tester.tap(find.text('my-app'));
    // The project slides in over the list rather than replacing it at once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('OpenCode 2.0.0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('OpenCode 2.0.0'), findsNothing);
    expect(find.text('Fix the login bug'), findsOneWidget);

    // The Git tab lists changed files and opens their diff.
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(find.text('fix-login'), findsOneWidget);
    expect(find.text('login.dart'), findsOneWidget);
    await tester.tap(find.text('login.dart'));
    await tester.pumpAndSettle();
    expect(find.text('+new'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The Files tab browses folders and opens a file.
    await tester.tap(find.text('ファイル'));
    await tester.pumpAndSettle();
    expect(find.text('lib'), findsOneWidget);
    await tester.tap(find.text('README.md'));
    await tester.pumpAndSettle();
    expect(find.text('# My app'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The MCP tab toggles a server's connection.
    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();
    expect(find.text('github'), findsOneWidget);
    expect(find.text('接続中'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(replies.last.path, '/api/mcp/github/disconnect');

    await tester.tap(find.text('セッション'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fix the login bug'));
    await tester.pumpAndSettle();
    expect(find.text('Please fix login'), findsOneWidget);
    expect(
      find.textContaining('The bug is', findRichText: true),
      findsOneWidget,
    );

    // The todo list and a pending permission show around the transcript.
    expect(find.text('Todo 1/2'), findsOneWidget);
    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('「bash」の許可が必要です'), findsOneWidget);
    expect(find.text('git push'), findsOneWidget);
    await tester.tap(find.byKey(const Key('permission-once')));
    await tester.pumpAndSettle();
    expect(jsonDecode(replies.last.data as String), {'decision': 'once'});
    expect(find.text('「bash」の許可が必要です'), findsNothing);

    // A question arrives live and is answered with the option's value.
    send('form.created', {
      'form': {
        'id': 'frm_1',
        'sessionID': 's1',
        'title': 'Deploy now?',
        'fields': [
          {
            'key': 'proceed',
            'type': 'string',
            'required': true,
            'options': [
              {'value': 'yes', 'label': 'Yes'},
              {'value': 'no', 'label': 'No'},
            ],
          },
        ],
      },
    });
    await tester.pumpAndSettle();
    expect(find.text('Deploy now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('入力してください'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('form-submit')));
    await tester.pumpAndSettle();
    expect(jsonDecode(replies.last.data as String), {
      'answer': {'proceed': 'yes'},
    });
    expect(find.text('Deploy now?'), findsNothing);

    // A reply streams in live.
    send('session.execution.started', {});
    send('session.step.started', {'assistantMessageID': 'a2'});
    send('session.text.started', {'assistantMessageID': 'a2', 'ordinal': 0});
    send('session.text.delta', {
      'assistantMessageID': 'a2',
      'ordinal': 0,
      'delta': 'Streaming ',
    });
    send('session.text.delta', {
      'assistantMessageID': 'a2',
      'ordinal': 0,
      'delta': 'works',
    });
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Streaming works', findRichText: true),
      findsOneWidget,
    );
    send('session.execution.succeeded', {});
    await tester.pumpAndSettle();

    // Sending shows a pending bubble until the server promotes the input.
    await tester.enterText(find.byKey(const Key('composer')), 'Add a test');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    expect(find.text('Add a test'), findsOneWidget);
    expect(find.text('送信中…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(promptIds, hasLength(1));

    send('session.input.admitted', {
      'inputID': promptIds.single,
      'input': {
        'type': 'user',
        'data': {'text': 'Add a test'},
      },
    });
    send('session.input.promoted', {'inputID': promptIds.single});
    await tester.pumpAndSettle();
    expect(find.text('Add a test'), findsOneWidget);
    expect(find.text('送信中…'), findsNothing);

    // An attached image is sent inline, even without text.
    await tester.tap(find.byKey(const Key('attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-library')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attachment-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(promptBodies.last['text'], '');
    expect(promptBodies.last['files'], [
      {'uri': 'data:image/png;base64,AQID', 'name': 'shot.png'},
    ]);
    expect(find.byKey(const Key('attachment-0')), findsNothing);

    // Renaming from the menu updates the title.
    await tester.tap(find.byKey(const Key('session-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名前を変更'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-field')),
      'Login fixed',
    );
    await tester.tap(find.byKey(const Key('confirm-rename')));
    await tester.pumpAndSettle();
    expect(replies.reversed.skip(1).first.method, 'PATCH');
    expect(find.text('Login fixed'), findsOneWidget);

    final saved = await store.loadServers();
    expect(saved.single.baseUrl, 'http://example.test:4096');
    expect(await store.readPassword(saved.single.id), 'pw');

    // Tear down the app so the event stream closes its timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
