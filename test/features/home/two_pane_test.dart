import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/chat/chat_screen.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/home/two_pane_home.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_discovery.dart';

Map<String, Object?> _session(String id, String title) => {
  'id': id,
  'projectID': 'abc',
  'title': title,
  'location': {'directory': '/home/me/my-app'},
  'time': {'created': 1, 'updated': 2},
};

const _tablet = Size(1180, 820);
const _phone = Size(390, 844);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  /// Starts the app at [size] and connects to a server with one project
  /// and two sessions.
  Future<void> connect(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
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
        'data': [_session('s1', 'First one'), _session('s2', 'Second one')],
      }),
      '/api/session/active': FakeRoute.json({'data': {}}),
      '/api/permission/request': FakeRoute.json({'data': []}),
      for (final id in ['s1', 's2'])
        '/api/session/$id/message': FakeRoute.json({
          'data': [
            {
              'id': 'u-$id',
              'type': 'user',
              'time': {'created': 1},
              'text': 'Hello from $id',
            },
          ],
        }),
    });
    final events = StreamController<List<int>>();
    addTearDown(events.close);
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
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
  }

  Finder backButton() => find.byType(BackButton);

  testWidgets('a tablet shows the session list and the chat side by side', (
    tester,
  ) async {
    await connect(tester, _tablet);
    expect(find.byType(TwoPaneHome), findsOneWidget);
    expect(find.text('セッションを選ぶと\nここにチャットが表示されます'), findsOneWidget);

    await tester.tap(find.text('my-app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First one'));
    await tester.pumpAndSettle();
    expect(find.text('Hello from s1'), findsOneWidget);
    // Both panes stay on the one page.
    expect(find.text('Second one'), findsOneWidget);
    final chat = tester.getRect(find.byType(ChatScreen));
    expect(chat.left, greaterThan(TwoPaneHome.listWidth));
    // Only the list has a back button, and it leads to the projects.
    expect(backButton(), findsOneWidget);
    expect(tester.getRect(backButton()).left, lessThan(chat.left));

    await tester.tap(find.text('Second one'));
    await tester.pumpAndSettle();
    expect(find.text('Hello from s2'), findsOneWidget);
    expect(find.text('Hello from s1'), findsNothing);

    await tester.tap(backButton());
    await tester.pumpAndSettle();
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('Hello from s2'), findsOneWidget);
  });

  testWidgets('narrowing the window keeps the open session as pages, and '
      'widening folds them back into the panes', (tester) async {
    await connect(tester, _tablet);
    await tester.tap(find.text('my-app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First one'));
    await tester.pumpAndSettle();

    await resize(tester, _phone);
    expect(find.byType(TwoPaneHome), findsNothing);
    expect(find.text('Hello from s1'), findsOneWidget);
    // Back from the chat page reaches the project's sessions page.
    await tester.tap(backButton());
    await tester.pumpAndSettle();
    expect(find.text('First one'), findsOneWidget);
    expect(find.text('Hello from s1'), findsNothing);

    await resize(tester, _tablet);
    expect(find.byType(TwoPaneHome), findsOneWidget);
    // The project stays open on the left; the closed chat stays closed.
    expect(find.text('First one'), findsOneWidget);
    expect(find.text('セッションを選ぶと\nここにチャットが表示されます'), findsOneWidget);

    await tester.tap(find.text('Second one'));
    await tester.pumpAndSettle();
    await resize(tester, _phone);
    await resize(tester, _tablet);
    expect(find.byType(TwoPaneHome), findsOneWidget);
    expect(find.text('Hello from s2'), findsOneWidget);
    // In the list and as the chat's title.
    expect(find.text('Second one'), findsNWidgets(2));
    expect(backButton(), findsOneWidget);
  });

  testWidgets('a phone turned sideways keeps single pages', (tester) async {
    await connect(tester, const Size(932, 430));
    expect(find.byType(TwoPaneHome), findsNothing);
    await tester.tap(find.text('my-app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First one'));
    await tester.pumpAndSettle();
    expect(find.text('Hello from s1'), findsOneWidget);
    expect(find.text('Second one'), findsNothing);
  });
}
