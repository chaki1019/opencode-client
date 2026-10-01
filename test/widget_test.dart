import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/main.dart';

import 'support/fake_adapter.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('connecting shows the project list and saves the server', (
    tester,
  ) async {
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
    });
    final store = ServerStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverStoreProvider.overrideWithValue(store),
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

    final saved = await store.loadServers();
    expect(saved.single.baseUrl, 'http://example.test:4096');
    expect(await store.readPassword(saved.single.id), 'pw');
  });
}
