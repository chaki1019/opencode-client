import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/push/push_config.dart';
import 'package:opencode_mobile/core/push/push_message.dart';
import 'package:opencode_mobile/core/push/push_messaging.dart';
import 'package:opencode_mobile/core/push/push_store.dart';
import 'package:opencode_mobile/core/push/relay_client.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/chat/chat_screen.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/features/push/push_providers.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_discovery.dart';

const _config = PushConfig(
  relayUrl: 'https://relay.test',
  projectId: 'demo',
  senderId: '123',
  androidApiKey: 'a',
  androidAppId: '1:123:android:abc',
  iosApiKey: 'i',
  iosAppId: '1:123:ios:abc',
  iosBundleId: 'com.example.app',
);

class _FakeMessaging implements PushMessaging {
  bool allow = true;
  final tapController = StreamController<PushMessage>.broadcast();
  final foregroundController = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<String?> token() async => 'fcm-token';

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get taps => tapController.stream;

  @override
  Stream<PushMessage> get foreground => foregroundController.stream;

  @override
  Future<PushMessage?> initialTap() async => null;
}

void main() {
  late _FakeMessaging messaging;
  late FakeAdapter server;
  late FakeAdapter relay;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    messaging = _FakeMessaging();
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
      '/api/session/ses_1': FakeRoute.json({
        'data': {
          'id': 'ses_1',
          'projectID': 'abc',
          'title': 'Fix login',
          'location': {'directory': '/home/me/my-app'},
          'time': {'created': 1, 'updated': 2},
        },
      }),
    });
    relay = FakeAdapter({
      '/v1/devices': FakeRoute.json({'ok': true}),
      '/v1/notify': FakeRoute.json({'ok': true, 'delivered': 1}, status: 202),
    });
  });

  Future<void> pumpConnected(WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noDiscoveryOverrides,
          serverStoreProvider.overrideWithValue(ServerStore()),
          eventStreamProvider.overrideWith((ref) {
            if (ref.watch(connectionProvider) == null) return null;
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
          pushConfigProvider.overrideWithValue(_config),
          pushMessagingProvider.overrideWithValue(messaging),
          relayClientProvider.overrideWithValue(
            RelayClient(_config.relayUrl, dio: fakeDio(relay)),
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
    // Keep the server when asked after connecting.
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> body(RequestOptions r) =>
      (r.data as Map).cast<String, Object?>();

  testWidgets('turning notifications on registers the device and shows the '
      'plugin entry', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await pumpConnected(tester);

    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    expect(find.text('このサーバーの通知を受け取る'), findsOneWidget);
    expect(find.byKey(const Key('push-snippet')), findsNothing);

    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();

    final register = relay.requests.single;
    expect(register.method, 'POST');
    expect(register.path, '/v1/devices');
    final key = body(register)['key']! as String;
    expect(key, hasLength(43));
    expect(body(register)['token'], 'fcm-token');

    final snippet = tester
        .widget<SelectableText>(find.byKey(const Key('push-snippet')))
        .data!;
    final entry = jsonDecode('{$snippet}') as Map<String, Object?>;
    expect(entry['plugins'], [
      {
        'package': './plugins/opencode-push.js',
        'options': {'relay': 'https://relay.test', 'key': key},
      },
    ]);
    await tester.tap(find.byKey(const Key('push-copy')));
    await tester.pumpAndSettle();
    expect(clipboard.single, snippet);

    await tester.tap(find.byKey(const Key('push-test')));
    await tester.pumpAndSettle();
    final test = relay.requests.last;
    expect(test.path, '/v1/notify');
    expect(test.headers['Authorization'], 'Bearer $key');
    expect(find.text('送信しました。数秒で届きます。'), findsOneWidget);

    // Turning it off unregisters the same token.
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    final unregister = relay.requests.last;
    expect(unregister.method, 'DELETE');
    expect(body(unregister), {'key': key, 'token': 'fcm-token'});
    expect(find.byKey(const Key('push-snippet')), findsNothing);
  });

  testWidgets('a denied permission leaves notifications off', (tester) async {
    messaging.allow = false;
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();

    expect(find.text('システム設定でこのアプリの通知がオフになっています'), findsOneWidget);
    expect(relay.requests, isEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('push-switch'))).value,
      isFalse,
    );
  });

  testWidgets('tapping a notification opens its session', (tester) async {
    await pumpConnected(tester);
    final saved = (await ServerStore().loadServers()).single;
    final pairing = PushPairing(key: PushPairing.newKey(), enabled: true);
    await PushStore().save(saved.id, pairing);

    // Another server's notification is ignored.
    messaging.tapController.add(
      PushMessage(
        kind: PushKind.completed,
        keyId: pairingKeyId('someone-else'),
        sessionId: 'ses_1',
        directory: '',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);

    messaging.tapController.add(
      PushMessage(
        kind: PushKind.completed,
        keyId: pairingKeyId(pairing.key),
        sessionId: 'ses_1',
        directory: '/home/me/my-app',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(server.requests.map((r) => r.path), contains('/api/session/ses_1'));
  });

  testWidgets('a notification in the foreground shows a snack bar', (
    tester,
  ) async {
    await pumpConnected(tester);
    messaging.foregroundController.add(
      PushMessage(
        kind: PushKind.permission,
        keyId: 'x',
        sessionId: 'ses_1',
        directory: '',
        title: 'my-app: 許可を待っています',
        body: 'Fix login',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('my-app: 許可を待っています\nFix login'), findsOneWidget);
    expect(find.text('開く'), findsOneWidget);
  });

  test('message data and key ids match the relay', () {
    // Same input as the relay's keyId(): hex SHA-256.
    expect(
      pairingKeyId('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    final message = PushMessage.fromData({
      'kind': 'question',
      'keyId': 'k',
      'sessionID': 'ses_9',
      'directory': '/w',
    }, title: 't');
    expect(message?.kind, PushKind.question);
    expect(message?.sessionId, 'ses_9');
    expect(PushMessage.fromData({'keyId': 'k', 'sessionID': ''}), isNull);
    final key = PushPairing.newKey();
    expect(key, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
  });
}
