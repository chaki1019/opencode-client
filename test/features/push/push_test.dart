import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/push/push_config.dart';
import 'package:opencode_mobile/core/push/push_crypto.dart';
import 'package:opencode_mobile/core/push/push_inbox.dart';
import 'package:opencode_mobile/core/push/push_message.dart';
import 'package:opencode_mobile/core/push/push_messaging.dart';
import 'package:opencode_mobile/core/push/push_store.dart';
import 'package:opencode_mobile/core/push/relay_client.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/chat/chat_screen.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/features/push/push_providers.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
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

  final shared = <String>{};

  @override
  Future<void> shareKeys(PushKeys keys) async => shared.add(keys.keyId);

  @override
  Future<void> unshareKeys(String keyId) async => shared.remove(keyId);
}

Future<String> _seal(
  String pairingKey,
  PushKind kind,
  String session,
  PushContent content,
) async => sealPushContent(
  encKey: (await PushKeys.derive(pairingKey)).encKey,
  kind: kind.name,
  sessionId: session,
  content: content,
);

void main() {
  late _FakeMessaging messaging;
  late FakeAdapter server;
  late FakeAdapter relay;
  String? latestPlugin;

  setUp(() {
    latestPlugin = null;
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
      '/api/plugin': FakeRoute.json({'location': {}, 'data': []}),
      '/api/config': FakeRoute.json([]),
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
          pushConfigProvider.overrideWithValue(_config),
          latestPushPluginVersionProvider.overrideWith(
            (ref) async => latestPlugin,
          ),
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

    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    expect(find.text('このサーバーの通知を受け取る'), findsOneWidget);
    expect(find.byKey(const Key('push-snippet')), findsNothing);

    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();

    final register = relay.requests.single;
    expect(register.method, 'POST');
    expect(register.path, '/v1/devices');
    expect(body(register)['token'], 'fcm-token');

    final snippet = tester
        .widget<SelectableText>(find.byKey(const Key('push-snippet')))
        .data!;
    final entry = jsonDecode('{$snippet}') as Map<String, Object?>;
    // The plugin makes its own key; only a non-public relay is passed.
    expect(entry['plugins'], [
      {
        'package': 'opencode-mobile-push',
        'options': {'relay': 'https://relay.test'},
      },
    ]);
    final saved = (await ServerStore().loadServers()).single;
    final key = (await PushStore().load(saved.id))!.key;
    expect(key, hasLength(43));
    expect(find.text('まだ設定されていません。下の手順で追加してください。'), findsOneWidget);

    // Once OpenCode runs the plugin with this key, the screen says so.
    server.routes['/api/plugin'] = FakeRoute.json({
      'location': {'directory': '/home/me'},
      'data': [
        {
          'id': 'opencode-mobile-push',
          'source': {'type': 'package', 'target': 'opencode-mobile-push'},
          'features': {'server': true},
          'state': {'status': 'active'},
        },
      ],
    });
    server.routes['/api/config'] = FakeRoute.json([
      {
        'type': 'document',
        'path': '/home/me/.config/opencode/opencode.json',
        'info': {
          'plugins': [
            {
              'package': 'opencode-mobile-push',
              'options': {'relay': 'https://relay.test', 'key': key},
            },
          ],
        },
      },
    ]);
    await tester.tap(find.byKey(const Key('push-computer-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('稼働中'), findsOneWidget);
    // The relay only ever gets the derived auth key, and the iOS extension
    // gets the decryption key.
    final keys = await tester.runAsync(() => PushKeys.derive(key));
    expect(body(register)['key'], keys!.auth);
    expect(body(register)['key'], isNot(key));
    expect(messaging.shared, {keys.keyId});
    await tester.tap(find.byKey(const Key('push-copy')));
    await tester.pumpAndSettle();
    expect(clipboard.single, snippet);

    await tester.tap(find.byKey(const Key('push-test')));
    await tester.pumpAndSettle();
    final test = relay.requests.last;
    expect(test.path, '/v1/notify');
    expect(test.headers['Authorization'], 'Bearer ${keys.auth}');
    expect(body(test).keys, unorderedEquals(['kind', 'sessionID', 'enc']));
    final opened = await tester.runAsync(
      () => openPushContent(
        encKey: keys.encKey,
        kind: 'completed',
        sessionId: '',
        enc: body(test)['enc']! as String,
      ),
    );
    expect(opened?.title, 'OpenCode からのテスト通知');
    expect(find.text('送信しました。数秒で届きます。'), findsOneWidget);

    // Turning it off unregisters the same token.
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    final unregister = relay.requests.last;
    expect(unregister.method, 'DELETE');
    expect(body(unregister), {'key': keys.auth, 'token': 'fcm-token'});
    expect(messaging.shared, isEmpty);
    expect(find.byKey(const Key('push-snippet')), findsNothing);
  });

  testWidgets('the key the plugin made on the computer is adopted', (
    tester,
  ) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    final ownAuth = body(relay.requests.single)['key'];

    // OpenCode loads the plugin by name only; it saved its own key next to
    // opencode.json.
    final shared = 'S' * 43;
    server.routes['/api/plugin'] = FakeRoute.json({
      'location': {'directory': '/home/me'},
      'data': [
        {
          'id': 'opencode-mobile-push',
          'source': {'type': 'package', 'target': 'opencode-mobile-push'},
          'features': {'server': true},
          'state': {'status': 'active'},
        },
      ],
    });
    server.routes['/api/config'] = FakeRoute.json([
      {
        'type': 'document',
        'path': '/home/me/.config/opencode/opencode.json',
        'info': {
          'plugins': ['opencode-mobile-push'],
        },
      },
    ]);
    server.routes['/api/fs/read/opencode-mobile-push.json'] = (request) =>
        request.queryParameters['location[directory]'] ==
            '/home/me/.config/opencode'
        ? FakeRoute.json({'relay': 'https://relay.test', 'key': shared})
        : const FakeRoute(404, 'Not Found', contentType: 'text/plain');
    await tester.tap(find.byKey(const Key('push-computer-refresh')));
    await tester.pumpAndSettle();

    final sharedKeys = await tester.runAsync(() => PushKeys.derive(shared));
    final unregister = relay.requests[relay.requests.length - 2];
    final register = relay.requests.last;
    expect(unregister.method, 'DELETE');
    expect(body(unregister)['key'], ownAuth);
    expect(register.method, 'POST');
    expect(body(register)['key'], sharedKeys!.auth);
    expect(messaging.shared, {sharedKeys.keyId});
    expect(find.text('稼働中'), findsOneWidget);
    final saved = (await ServerStore().loadServers()).single;
    expect((await PushStore().load(saved.id))!.key, shared);
  });

  testWidgets('a key in opencode.json is adopted before turning it on', (
    tester,
  ) async {
    final shared = 'T' * 43;
    server.routes['/api/config'] = FakeRoute.json([
      {
        'type': 'document',
        'info': {
          'plugins': [
            {
              'package': 'opencode-mobile-push',
              'options': {'relay': 'https://relay.test', 'key': shared},
            },
          ],
        },
      },
    ]);
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();

    // Registered once, straight with the computer's key.
    final sharedKeys = await tester.runAsync(() => PushKeys.derive(shared));
    expect(body(relay.requests.single)['key'], sharedKeys!.auth);
    expect(
      find.text('設定はありますが、まだ読み込まれていません。OpenCode を再起動してください。'),
      findsOneWidget,
    );
  });

  testWidgets('a denied permission leaves notifications off', (tester) async {
    messaging.allow = false;
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
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

  testWidgets('with several servers, the menu lists them to choose from', (
    tester,
  ) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-server')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('url')), 'second.test:4096');
    await tester.enterText(find.byKey(const Key('password')), 'pw');
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('save-name')), '会社');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('push-server-') &&
          !(w.key! as ValueKey<String>).value.startsWith('push-server-status-'),
    );
    expect(tiles, findsNWidgets(2));
    expect(find.byKey(const Key('push-switch')), findsNothing);

    // The server not on screen opens without switching to it.
    await tester.tap(find.text('example.test'));
    await tester.pumpAndSettle();
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('push-switch')),
    );
    expect((toggle.subtitle! as Text).data, 'example.test');

    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // The fake computer has no plugin yet.
    expect(find.text('オン · PC/Mac 側の設定を確認してください'), findsOneWidget);
    expect(find.text('オフ'), findsOneWidget);
  });

  testWidgets('tapping a notification opens its session', (tester) async {
    await pumpConnected(tester);
    final saved = (await ServerStore().loadServers()).single;
    final pairing = PushPairing(key: PushPairing.newKey(), enabled: true);
    await PushStore().save(saved.id, pairing);

    final ids = await tester.runAsync(
      () async => (
        mine: (await PushKeys.derive(pairing.key)).keyId,
        other: (await PushKeys.derive('someone-else')).keyId,
      ),
    );

    // Another server's notification is ignored.
    messaging.tapController.add(
      PushMessage(
        kind: PushKind.completed,
        keyId: ids!.other,
        sessionId: 'ses_1',
        enc: '',
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);

    messaging.tapController.add(
      PushMessage(
        kind: PushKind.completed,
        keyId: ids.mine,
        sessionId: 'ses_1',
        enc: '',
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(server.requests.map((r) => r.path), contains('/api/session/ses_1'));
  });

  testWidgets('a notification in the foreground shows a snack bar', (
    tester,
  ) async {
    await pumpConnected(tester);
    final saved = (await ServerStore().loadServers()).single;
    final pairing = PushPairing(key: PushPairing.newKey(), enabled: true);
    await PushStore().save(saved.id, pairing);
    final sealed = await tester.runAsync(
      () async => (
        keyId: (await PushKeys.derive(pairing.key)).keyId,
        enc: await _seal(
          pairing.key,
          PushKind.permission,
          'ses_1',
          const PushContent(project: 'my-app', title: 'Fix login'),
        ),
      ),
    );
    messaging.foregroundController.add(
      PushMessage(
        kind: PushKind.permission,
        keyId: sealed!.keyId,
        sessionId: 'ses_1',
        enc: sealed.enc,
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('my-app: 許可を待っています\nFix login'), findsOneWidget);
    expect(find.text('開く'), findsOneWidget);
  });

  test('decrypts the payload shared with the plugin', () async {
    final vector = jsonDecode(
      File('push/test-vector.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final keys = await PushKeys.derive(vector['key'] as String);
    expect(keys.auth, vector['auth']);
    // The relay's keyId() is hex SHA-256 of the auth key.
    expect(keys.keyId, vector['keyId']);
    final content = await openPushContent(
      encKey: keys.encKey,
      kind: vector['kind'] as String,
      sessionId: vector['sessionID'] as String,
      enc: vector['enc'] as String,
    );
    expect(content?.toJson(), vector['content']);
    // Bound to its kind and session.
    expect(
      await openPushContent(
        encKey: keys.encKey,
        kind: 'failed',
        sessionId: vector['sessionID'] as String,
        enc: vector['enc'] as String,
      ),
      isNull,
    );
  });

  test('notification text and message data', () async {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(
      pushText(
        l10n,
        PushKind.completed,
        const PushContent(project: 'my-app', title: 'Fix login'),
      ),
      (title: 'my-app: 応答が完了しました', body: 'Fix login'),
    );
    // Undecryptable content still says what happened.
    expect(pushText(l10n, PushKind.question, null), (
      title: '質問に回答を待っています',
      body: '',
    ));

    final message = PushMessage.fromData({
      'kind': 'question',
      'keyId': 'k',
      'sessionID': 'ses_9',
      'enc': 'e',
    });
    expect(message?.kind, PushKind.question);
    expect(message?.toData(), {
      'kind': 'question',
      'keyId': 'k',
      'sessionID': 'ses_9',
      'enc': 'e',
    });
    expect(PushMessage.fromData({'kind': 'completed'}), isNull);
    expect(PushPairing.newKey(), matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
  });

  testWidgets('an outdated plugin on the computer is updated through '
      'OpenCode', (tester) async {
    latestPlugin = '0.3.0';
    Map<String, Object?> plugin(String version) => {
      'location': {'directory': '/home/me'},
      'data': [
        {
          'id': 'opencode-mobile-push',
          'source': {
            'type': 'package',
            'target': 'opencode-mobile-push',
            'version': version,
          },
          'features': {'server': true},
          'state': {'status': 'active'},
        },
      ],
    };
    server.routes['/api/plugin'] = FakeRoute.json(plugin('0.2.0'));
    server.routes['/api/plugin/update'] = (RequestOptions request) {
      server.routes['/api/plugin'] = FakeRoute.json(plugin('0.3.0'));
      return const FakeRoute(204, '');
    };
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();

    expect(find.text('プッシュ通知プラグイン'), findsOneWidget);
    expect(find.textContaining('バージョン 0.2.0'), findsOneWidget);
    expect(find.text('新しいバージョン 0.3.0 があります'), findsOneWidget);

    await tester.tap(find.byKey(const Key('push-plugin-update')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final update = server.requests.lastWhere(
      (r) => r.path == '/api/plugin/update',
    );
    expect(update.method, 'POST');
    expect(jsonDecode(update.data as String), {
      'targets': ['opencode-mobile-push'],
    });
    expect(find.textContaining('バージョン 0.3.0'), findsOneWidget);
    expect(find.byKey(const Key('push-plugin-update')), findsNothing);
    expect(find.text('プラグインを更新しました'), findsOneWidget);
  });
}
