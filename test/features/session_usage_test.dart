import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/chat/context_sheet.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/main.dart';

import '../support/fake_adapter.dart';
import '../support/fake_discovery.dart';

Map<String, Object?> _session(String id, String title, {double? cost}) => {
  'id': id,
  'projectID': 'abc',
  'title': title,
  'location': {'directory': '/home/me/my-app'},
  'time': {'created': 1, 'updated': 2},
  'model': {'providerID': 'go', 'id': 'flash'},
  'cost': ?cost,
  'tokens': {
    'input': 1000,
    'output': 2000,
    'reasoning': 0,
    'cache': {'read': 3000, 'write': 0},
  },
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('the session list shows what each session is doing, and the '
      'chat opens its context usage', (tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    // The running dot would otherwise pulse forever.
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

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
          _session('s1', 'Waiting one', cost: 0.0234),
          _session('s2', 'Running one'),
          _session('s3', 'Quiet one'),
        ],
      }),
      '/api/session/active': FakeRoute.json({
        'data': {
          's2': {'type': 'running'},
        },
      }),
      '/api/permission/request': FakeRoute.json({
        'data': [
          {
            'id': 'per_1',
            'sessionID': 's1',
            'action': 'bash',
            'resources': ['ls'],
          },
        ],
      }),
      // No question list on this server: the 404 is skipped.
      '/api/session/s1': FakeRoute.json({
        'data': _session('s1', 'Waiting one', cost: 0.0234),
      }),
      '/api/session/s1/message': FakeRoute.json({
        'data': [
          {
            'id': 'a1',
            'type': 'assistant',
            'model': {'providerID': 'go', 'id': 'flash'},
            'time': {'created': 1, 'completed': 2},
            'cost': 0.01,
            'tokens': {
              'input': 532,
              'output': 512,
              'reasoning': 0,
              'cache': {'read': 58368, 'write': 0},
            },
            'content': [
              {'type': 'text', 'text': 'Done.'},
            ],
          },
        ],
      }),
      '/api/provider': FakeRoute.json({
        'data': [
          {'id': 'go', 'name': 'OpenCode Go'},
        ],
      }),
      '/api/model': FakeRoute.json({
        'data': [
          {
            'id': 'flash',
            'providerID': 'go',
            'name': 'DeepSeek Flash',
            'limit': {'context': 1000000, 'output': 8192},
          },
        ],
      }),
    });
    final events = StreamController<List<int>>();
    void send(String type, Map<String, Object?> data) => events.add(
      utf8.encode('data: ${jsonEncode({'type': type, 'data': data})}\n\n'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noDiscoveryOverrides,
          serverStoreProvider.overrideWithValue(ServerStore()),
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
    await tester.tap(find.text('my-app'));
    await tester.pumpAndSettle();

    // No generic icon: only sessions with something going on are marked.
    final quietTile = find.ancestor(
      of: find.text('Quiet one'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: quietTile, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(find.text('対応待ち'), findsOneWidget);
    expect(find.text('実行中'), findsOneWidget);
    expect(find.text('エラー'), findsNothing);
    expect(find.textContaining(r'$0.02', findRichText: true), findsOneWidget);
    final permissionLoad = adapter.requests.firstWhere(
      (r) => r.path == '/api/permission/request',
    );
    expect(permissionLoad.queryParameters, {
      'location[directory]': '/home/me/my-app',
    });

    // Live events move the markers.
    send('permission.replied', {'sessionID': 's1', 'requestID': 'per_1'});
    send('session.execution.failed', {'sessionID': 's3'});
    send('permission.v2.asked', {
      'id': 'per_2',
      'sessionID': 's2',
      'action': 'edit',
      'resources': ['a.txt'],
    });
    await tester.pumpAndSettle();
    expect(find.text('エラー'), findsOneWidget);
    expect(find.text('対応待ち'), findsOneWidget);
    expect(find.text('実行中'), findsNothing);
    final s2Tile = find.ancestor(
      of: find.text('Running one'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: s2Tile, matching: find.text('対応待ち')),
      findsOneWidget,
    );

    // The chat's context ring opens the usage sheet.
    await tester.tap(find.text('Waiting one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('context-usage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('context-percent')), findsOneWidget);
    expect(find.text('6%'), findsWidgets);
    expect(find.text('59,412 トークン使用'), findsOneWidget);
    expect(find.text('OpenCode Go'), findsOneWidget);
    expect(find.text('DeepSeek Flash'), findsOneWidget);
    expect(find.text('1,000,000'), findsOneWidget);
    expect(find.text('58,368 / 0'), findsOneWidget);
    expect(find.text(r'$0.02'), findsWidgets);

    // Reloading the transcript lives in the overflow menu.
    Navigator.of(tester.element(find.byType(ContextSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsNothing);
    int messageLoads() => adapter.requests
        .where((r) => r.path == '/api/session/s1/message')
        .length;
    final before = messageLoads();
    await tester.tap(find.byKey(const Key('session-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();
    expect(messageLoads(), before + 1);
  });
}
