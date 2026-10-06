import 'dart:async';
import 'dart:convert';

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

  /// Each connected server's event feed, by server ID.
  final serverEvents = <String, StreamController<List<int>>>{};
  void send(String serverId, String type, String sessionId) =>
      serverEvents[serverId]!.add(
        utf8.encode(
          'data: ${jsonEncode({
            'type': type,
            'data': {'sessionID': sessionId},
          })}\n\n',
        ),
      );
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
    // Tall enough that the saved and found lists sit on screen, and narrow
    // enough to be a phone rather than a tablet with two panes.
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverEventStreamProvider.overrideWith((ref, serverId) {
            final events = serverEvents[serverId] = StreamController();
            // A closed feed is a server that went away.
            final stream = EventStream(
              open: (_) async => events.isClosed
                  ? throw StateError('unreachable')
                  : events.stream,
            )..start();
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

  group('drawer', () {
    Future<void> saveServers(List<ServerConfig> servers) async {
      final store = ServerStore();
      await store.saveServers(servers);
      for (final s in servers) {
        await store.writePassword(s.id, 'secret');
      }
    }

    Future<void> openDrawer(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-drawer')));
      await tester.pumpAndSettle();
    }

    String title(WidgetTester tester) =>
        (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!;

    const home = ServerConfig(
      id: 'home',
      baseUrl: 'http://home.test:4096',
      label: '自宅',
    );
    const work = ServerConfig(
      id: 'work',
      baseUrl: 'http://work.test:4096',
      label: '職場',
    );
    const down = ServerConfig(
      id: 'down',
      baseUrl: 'http://down.test:4096',
      label: '停止中',
    );

    /// Connects one more saved server from the drawer's add screen.
    Future<void> addSaved(WidgetTester tester, String name) async {
      await openDrawer(tester);
      await tester.tap(find.byKey(const Key('add-server')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    Future<void> switchTo(WidgetTester tester, String id) async {
      await openDrawer(tester);
      await tester.tap(find.byKey(Key('drawer-server-$id')));
      await tester.pumpAndSettle();
    }

    List<String> listed(WidgetTester tester) {
      final tiles = find.descendant(
        of: find.byType(Drawer),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ListTile &&
              (w.key as ValueKey<String>?)?.value.startsWith(
                    'drawer-server-',
                  ) ==
                  true,
        ),
      );
      return [
        for (final tile in tester.widgetList<ListTile>(tiles))
          (tile.key! as ValueKey<String>).value.substring(
            'drawer-server-'.length,
          ),
      ];
    }

    bool selected(WidgetTester tester, String id) =>
        tester.widget<ListTile>(find.byKey(Key('drawer-server-$id'))).selected;

    testWidgets('lists the servers connected to, in a fixed order', (
      tester,
    ) async {
      await saveServers([home, work, down]);
      await pumpApp(tester);
      await tester.tap(find.text('自宅'));
      await tester.pumpAndSettle();

      // Saved servers not connected to are not listed.
      await openDrawer(tester);
      expect(listed(tester), ['home']);
      expect(serverEvents.keys, ['home']);
      await tester.tapAt(const Offset(420, 300));
      await tester.pumpAndSettle();

      await addSaved(tester, '職場');
      expect(title(tester), '職場');
      await openDrawer(tester);
      expect(listed(tester), ['home', 'work']);
      expect(selected(tester, 'work'), isTrue);
      expect(selected(tester, 'home'), isFalse);

      // Switching moves the highlight, not the rows.
      await tester.tap(find.byKey(const Key('drawer-server-home')));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(title(tester), '自宅');
      await openDrawer(tester);
      expect(listed(tester), ['home', 'work']);
      expect(selected(tester, 'home'), isTrue);
      expect(selected(tester, 'work'), isFalse);
    });

    testWidgets('keeps the other servers connected and shows their progress', (
      tester,
    ) async {
      await saveServers([home, work]);
      await pumpApp(tester);
      await tester.tap(find.text('自宅'));
      await tester.pumpAndSettle();
      await addSaved(tester, '職場');
      await switchTo(tester, 'home');

      send('work', 'session.execution.started', 'w1');
      send('work', 'session.execution.started', 'w2');
      send('work', 'session.execution.succeeded', 'w1');
      await tester.pump();

      await openDrawer(tester);
      String status(String id) => tester
          .widget<Text>(find.byKey(Key('drawer-server-status-$id')))
          .data!;
      expect(status('work'), '1件作業中 · 1件完了');
      expect(
        find.byKey(const Key('drawer-server-finished-work')),
        findsOneWidget,
      );
      expect(status('home'), 'http://home.test:4096');

      // Switching is instant and clears what was counted.
      final requests = adapter.requests.length;
      await tester.tap(find.byKey(const Key('drawer-server-work')));
      await tester.pumpAndSettle();
      expect(title(tester), '職場');
      expect(
        adapter.requests.skip(requests).where((r) => r.path == '/api/health'),
        isEmpty,
      );

      await openDrawer(tester);
      expect(status('work'), 'http://work.test:4096');
      expect(
        find.byKey(const Key('drawer-server-finished-work')),
        findsNothing,
      );
      // The one left behind is followed in turn.
      send('home', 'session.execution.started', 'h1');
      await tester.pumpAndSettle();
      expect(status('home'), '1件作業中');
    });

    testWidgets('keeps a server that dropped, saying it is unreachable', (
      tester,
    ) async {
      await saveServers([home, work]);
      await pumpApp(tester);
      await tester.tap(find.text('自宅'));
      await tester.pumpAndSettle();
      await addSaved(tester, '職場');
      await switchTo(tester, 'home');

      // The feed ends; the stream waits a moment before trying again.
      await serverEvents['work']!.close();
      await tester.pump(const Duration(seconds: 1));
      await openDrawer(tester);
      expect(listed(tester), ['home', 'work']);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('drawer-server-status-work')))
            .data,
        '接続できません',
      );
      // Lets the retry waiting on its backoff finish.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('opens diagnostics from the project list, not the drawer', (
      tester,
    ) async {
      await saveServers([home]);
      await pumpApp(tester);
      await tester.tap(find.text('自宅'));
      await tester.pumpAndSettle();
      await openDrawer(tester);
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('接続の診断')),
        findsNothing,
      );
      await tester.tapAt(const Offset(420, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diagnostics')), findsOneWidget);
    });

    testWidgets('adds a server and comes back to its projects', (tester) async {
      await saveServers([home]);
      await pumpApp(tester);
      await tester.tap(find.text('自宅'));
      await tester.pumpAndSettle();

      await openDrawer(tester);
      await tester.tap(find.byKey(const Key('add-server')));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      await connectTo(tester, '10.0.0.7:4096');
      await tester.enterText(find.byKey(const Key('save-name')), '新しい');
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(title(tester), '新しい');

      await openDrawer(tester);
      Finder inDrawer(String text) =>
          find.descendant(of: find.byType(Drawer), matching: find.text(text));
      expect(inDrawer('自宅'), findsOneWidget);
      expect(inDrawer('新しい'), findsOneWidget);
    });
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

  testWidgets('does not search the network until asked', (tester) async {
    await pumpApp(tester);
    expect(discovery.started, 0);
    expect(find.text('見つかりませんでした'), findsNothing);

    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    expect(discovery.started, 1);
    expect(find.byKey(const Key('scan')), findsNothing);
  });

  testWidgets('a server found on the network fills the URL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
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
