import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/main.dart';

import 'support/fake_adapter.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('connecting shows the project list and saves the server', (
    tester,
  ) async {
    final promptIds = <String>[];
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
      '/api/session/s1/prompt': (RequestOptions request) {
        final body = jsonDecode(request.data as String) as Map<String, dynamic>;
        promptIds.add(body['id'] as String);
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
    await tester.pumpAndSettle();
    expect(find.text('Fix the login bug'), findsOneWidget);

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
    expect(jsonDecode(replies.single.data as String), {'decision': 'once'});
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

    final saved = await store.loadServers();
    expect(saved.single.baseUrl, 'http://example.test:4096');
    expect(await store.readPassword(saved.single.id), 'pw');

    // Tear down the app so the event stream closes its timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
