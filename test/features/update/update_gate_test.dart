import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/update/update_checker.dart';
import 'package:opencode_mobile/features/config/remote_values.dart';
import 'package:opencode_mobile/features/update/update_gate.dart';
import 'package:opencode_mobile/features/update/update_providers.dart';
import 'package:opencode_mobile/main.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_discovery.dart';
import '../../support/fake_remote_settings.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  const url = 'https://relay.test/v1/app-version';

  Future<void> pumpApp(
    WidgetTester tester, {
    String minimum = '',
    FakeRemoteSettings? remote,
  }) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    final dio = fakeDio(
      FakeAdapter({
        url: FakeRoute.json({
          'android': {'minimum': minimum, 'storeUrl': null},
        }),
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noDiscoveryOverrides,
          updateCheckerProvider.overrideWithValue(UpdateChecker(url, dio: dio)),
          if (remote != null) remoteSettingsProvider.overrideWithValue(remote),
          packageInfoProvider.overrideWithValue(
            Future.value(
              PackageInfo(
                appName: 'OpenCode',
                packageName: 'dev.example.app',
                version: '1.0.0',
                buildNumber: '1',
              ),
            ),
          ),
        ],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an outdated app is replaced by the update screen', (
    tester,
  ) async {
    await pumpApp(tester, minimum: '1.1.0');
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    expect(find.text('アップデートが必要です'), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsOneWidget);
    // Android falls back to the Play listing for the package.
    expect(find.text('ストアを開く'), findsOneWidget);
    final screen = tester.widget<UpdateRequiredScreen>(
      find.byType(UpdateRequiredScreen),
    );
    expect(
      screen.update.storeUrl,
      'https://play.google.com/store/apps/details?id=dev.example.app',
    );
  });

  testWidgets('an up-to-date app runs normally', (tester) async {
    await pumpApp(tester, minimum: '1.0.0');
    expect(find.byType(UpdateRequiredScreen), findsNothing);
  });

  testWidgets('Remote Config\'s minimum wins over the relay', (tester) async {
    // The relay would block; a build with Remote Config does not ask it.
    await pumpApp(
      tester,
      minimum: '9.0.0',
      remote: FakeRemoteSettings({'app_version': '1.0.0'}),
    );
    expect(find.byType(UpdateRequiredScreen), findsNothing);
  });

  testWidgets('a raised minimum blocks while the app runs', (tester) async {
    final remote = FakeRemoteSettings();
    await pumpApp(tester, remote: remote);
    expect(find.byType(UpdateRequiredScreen), findsNothing);

    remote.push({'app_version': '1.1.0'});
    await tester.pumpAndSettle();
    final screen = tester.widget<UpdateRequiredScreen>(
      find.byType(UpdateRequiredScreen),
    );
    expect(
      screen.update.storeUrl,
      'https://play.google.com/store/apps/details?id=dev.example.app',
    );
  });
}
