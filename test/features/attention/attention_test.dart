import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/models/server_config.dart';
import 'package:opencode_mobile/core/push/push_crypto.dart';
import 'package:opencode_mobile/core/push/push_message.dart';
import 'package:opencode_mobile/core/push/push_messaging.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/attention/attention_providers.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/features/push/push_providers.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_discovery.dart';

class _FakeMessaging implements PushMessaging {
  int? badge;
  final cleared = <String>[];

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String?> token() async => 'fcm-token';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get taps => const Stream.empty();
  @override
  Stream<PushMessage> get foreground => const Stream.empty();
  @override
  Future<PushMessage?> initialTap() async => null;
  @override
  Future<void> shareKeys(PushKeys keys) async {}
  @override
  Future<void> unshareKeys(String keyId) async {}
  @override
  Future<void> clearSession(String sessionId) async => cleared.add(sessionId);
  @override
  Future<void> setBadge(int count) async => badge = count;
}

Map<String, Object?> _session(
  String id, {
  String? title,
  double? idle,
  double? viewed,
  String? outcome,
}) => {
  'id': id,
  'projectID': 'abc',
  'title': ?title,
  'location': {'directory': '/home/me/my-app'},
  'time': {'created': 1, 'updated': 2, 'idle': ?idle, 'viewed': ?viewed},
  'outcome': ?outcome,
};

void main() {
  final now = DateTime.now().millisecondsSinceEpoch.toDouble();
  const hour = 3600 * 1000.0;
  late FakeAdapter server;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeAdapter({
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
          _session('ses_run', title: 'Deploy'),
          _session(
            'ses_done',
            title: 'Fix login',
            idle: now - hour,
            outcome: 'succeeded',
          ),
          _session(
            'ses_fail',
            title: 'Migrate DB',
            idle: now - 2 * hour,
            viewed: now - 3 * hour,
            outcome: 'failed',
          ),
          // Seen, stopped by the user, or too old: not listed.
          _session(
            'ses_seen',
            idle: now - hour,
            viewed: now - hour,
            outcome: 'succeeded',
          ),
          _session('ses_stop', idle: now - hour, outcome: 'interrupted'),
          _session('ses_old', idle: now - 24 * 10 * hour, outcome: 'succeeded'),
        ],
      }),
      '/api/session/active': FakeRoute.json({
        'data': {
          'ses_run': {'type': 'running'},
        },
      }),
      '/api/session/ses_run/permission': FakeRoute.json({
        'data': [
          {
            'id': 'per_1',
            'sessionID': 'ses_run',
            'action': 'bash',
            'resources': ['rm -rf build'],
          },
        ],
      }),
      '/api/session/ses_run/form': FakeRoute.json({'data': []}),
      '/api/session/ses_done/view': const FakeRoute(204, ''),
      '/api/session/ses_fail/view': const FakeRoute(204, ''),
    });
  });

  test('lists waiting requests and unseen finished runs', () async {
    final client = OpenCodeClient(
      baseUrl: 'http://example.test:4096',
      username: 'opencode',
      password: 'pw',
      dio: fakeDio(server),
    );
    const config = ServerConfig(id: 's', baseUrl: 'http://example.test:4096');
    final items = await loadAttention(client, config);
    expect(
      {for (final i in items) i.session.id: i.kind},
      {
        'ses_run': AttentionKind.permission,
        'ses_done': AttentionKind.completed,
        'ses_fail': AttentionKind.failed,
      },
    );
  });

  /// Connects the app to [server] and saves it; returns the messaging fake.
  Future<_FakeMessaging> pumpConnected(WidgetTester tester) async {
    final messaging = _FakeMessaging();
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noDiscoveryOverrides,
          serverStoreProvider.overrideWithValue(ServerStore()),
          serverEventStreamProvider.overrideWith((ref, _) {
            final events = StreamController<List<int>>();
            final stream = EventStream(open: (_) async => events.stream)
              ..start();
            ref.onDispose(stream.dispose);
            return stream;
          }),
          clientFactoryProvider.overrideWithValue(
            (s, password) => OpenCodeClient(
              baseUrl: s.baseUrl,
              username: s.username,
              password: password,
              dio: fakeDio(server),
            ),
          ),
          pushMessagingProvider.overrideWithValue(messaging),
        ],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('url')), 'example.test:4096');
    await tester.enterText(find.byKey(const Key('password')), 'pw');
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    return messaging;
  }

  testWidgets('the drawer and list show what needs the user, and the badge '
      'matches', (tester) async {
    final messaging = await pumpConnected(tester);
    expect(messaging.badge, 3);
    expect(
      find.descendant(
        of: find.byKey(const Key('menu-badge')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('attention')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('attention')));
    await tester.pumpAndSettle();

    // Waiting requests first, then finished runs newest first.
    final titles = [
      for (final w in tester.widgetList<ListTile>(find.byType(ListTile)))
        ((w.title! as Text).data),
    ];
    expect(titles, ['Deploy', 'Fix login', 'Migrate DB']);
    expect(find.textContaining('許可を待っています'), findsOneWidget);

    // A finished run swiped away is marked as seen on the server.
    await tester.drag(find.text('Fix login'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    final view = server.requests.where(
      (r) => r.path == '/api/session/ses_done/view',
    );
    expect(view, hasLength(1));
    final data = view.single.data;
    expect(
      (data is String ? jsonDecode(data) : data as Map)['idle'],
      now - hour,
    );
    expect(find.text('Fix login'), findsNothing);
    expect(messaging.badge, 2);

    // A permission cannot be swiped away; it has to be answered.
    await tester.drag(find.text('Deploy'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Deploy'), findsOneWidget);

    // Opening a finished run from the list marks it as seen too.
    await tester.tap(find.text('Migrate DB'));
    // The chat keeps loading against the fake server, so it never settles.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(
      server.requests.where((r) => r.path == '/api/session/ses_fail/view'),
      hasLength(1),
    );
    expect(messaging.badge, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the project row counts its items and the session rows are '
      'marked', (tester) async {
    await pumpConnected(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('project-attention-abc')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('my-app'));
    // The running session's spinner never settles.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 500));
    for (final id in ['ses_run', 'ses_done', 'ses_fail']) {
      expect(find.byKey(Key('session-attention-$id')), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
