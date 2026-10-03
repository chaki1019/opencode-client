import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/discovery/server_discovery.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/models/server_config.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/features/projects/projects_screen.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_discovery.dart';

void main() {
  late FakeDiscovery discovery;
  final adapter = FakeAdapter({
    '/api/health': (RequestOptions request) {
      if (request.uri.host == 'down.test') {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'Connection refused',
        );
      }
      return FakeRoute.json({'healthy': true, 'version': '2.0.0', 'pid': 1});
    },
    '/api/location': FakeRoute.json({'project': <String, Object?>{}}),
    '/api/project': FakeRoute.json(<Object>[]),
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    discovery = FakeDiscovery();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    // Tall enough that the saved and found lists sit on screen.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventStreamProvider.overrideWith((ref) {
            if (ref.watch(connectionProvider) == null) return null;
            final events = StreamController<List<int>>();
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
          serverDiscoveryProvider.overrideWithValue(discovery),
          lanScanProvider.overrideWithValue(FakeDiscovery(finished: const [])),
        ],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> connectTo(WidgetTester tester, String url) async {
    await tester.enterText(find.byKey(const Key('url')), url);
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.tap(find.byKey(const Key('connect')));
    await tester.pumpAndSettle();
  }

  Future<void> disconnect(WidgetTester tester) async {
    await tester.tap(find.byTooltip('切断'));
    await tester.pumpAndSettle();
  }

  const askTitle = '接続できました。この接続先を保存しますか？';

  testWidgets('offers to save after connecting, named after the host', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('名前（任意）'), findsNothing);
    expect(find.byKey(const Key('save')), findsNothing);

    await connectTo(tester, '10.0.0.5:4096/');
    expect(find.text(askTitle), findsOneWidget);
    final name = tester.widget<TextField>(find.byKey(const Key('save-name')));
    expect(name.controller!.text, '10.0.0.5');

    await tester.enterText(find.byKey(const Key('save-name')), '自宅');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);

    final store = ServerStore();
    final saved = (await store.loadServers()).single;
    expect(saved.label, '自宅');
    expect(saved.baseUrl, 'http://10.0.0.5:4096');
    expect(await store.readPassword(saved.id), 'secret');

    // Connecting to a saved server again does not ask.
    await disconnect(tester);
    await connectTo(tester, '10.0.0.5:4096');
    expect(find.text(askTitle), findsNothing);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('does not ask again after "don\'t save"', (tester) async {
    await pumpApp(tester);
    await connectTo(tester, '10.0.0.5:4096');
    await tester.tap(find.byKey(const Key('dont-save')));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(await ServerStore().loadServers(), isEmpty);

    await disconnect(tester);
    await connectTo(tester, '10.0.0.5:4096');
    expect(find.text(askTitle), findsNothing);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('rejects a malformed URL before connecting', (tester) async {
    await pumpApp(tester);
    final before = adapter.requests.length;
    await connectTo(tester, 'htt@://192.168.0.14:4096');
    expect(
      find.text('URL の形式が正しくありません（例: http://192.168.1.10:4096）'),
      findsOneWidget,
    );
    expect(adapter.requests, hasLength(before));
  });

  testWidgets('says why when the server cannot be reached', (tester) async {
    await pumpApp(tester);
    await connectTo(tester, 'down.test:4096');
    expect(find.textContaining('サーバーに接続できませんでした'), findsOneWidget);
    expect(find.byType(ProjectsScreen), findsNothing);
  });

  testWidgets('long-pressing a saved server renames it', (tester) async {
    final store = ServerStore();
    await store.saveServers(const [
      ServerConfig(id: 's1', baseUrl: 'http://10.0.0.5:4096'),
    ]);
    await store.writePassword('s1', 'secret');
    await pumpApp(tester);

    await tester.longPress(find.text('10.0.0.5'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'secret'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-name')), '会社の Mac');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('会社の Mac'), findsOneWidget);
    final saved = (await store.loadServers()).single;
    expect(saved.id, 's1');
    expect(saved.label, '会社の Mac');
    expect(await store.readPassword('s1'), 'secret');
  });

  testWidgets('a server found on the network fills the URL', (tester) async {
    await pumpApp(tester);
    expect(find.text('見つかりませんでした'), findsOneWidget);

    discovery.controller.add(const [
      DiscoveredServer(
        name: 'opencode-4096',
        baseUrl: 'http://192.168.1.20:4096',
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('opencode-4096'));
    await tester.pumpAndSettle();

    final url = tester.widget<TextFormField>(find.byKey(const Key('url')));
    expect(url.controller!.text, 'http://192.168.1.20:4096');
  });
}
