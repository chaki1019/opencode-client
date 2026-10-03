import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/discovery/server_discovery.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_discovery.dart';

void main() {
  late FakeDiscovery discovery;

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
          serverDiscoveryProvider.overrideWithValue(discovery),
          lanScanProvider.overrideWithValue(FakeDiscovery(finished: const [])),
        ],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saves a named server without connecting', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('url')), '10.0.0.5:4096/');
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.enterText(find.widgetWithText(TextFormField, '名前（任意）'), '自宅');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('「自宅」を保存しました'), findsOneWidget);
    expect(find.text('自宅'), findsOneWidget);
    expect(find.text('opencode @ http://10.0.0.5:4096'), findsOneWidget);

    final store = ServerStore();
    final saved = (await store.loadServers()).single;
    expect(saved.label, '自宅');
    expect(await store.readPassword(saved.id), 'secret');
  });

  testWidgets('renames a saved server and keeps its password', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('url')), '10.0.0.5:4096');
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    final id = (await ServerStore().loadServers()).single.id;
    await tester.tap(find.byKey(Key('server-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'secret'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-name')), '会社の Mac');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('会社の Mac'), findsOneWidget);
    final store = ServerStore();
    final saved = (await store.loadServers()).single;
    expect(saved.id, id);
    expect(saved.label, '会社の Mac');
    expect(await store.readPassword(id), 'secret');
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
