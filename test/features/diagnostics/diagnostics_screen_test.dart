import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/api_errors.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/server_config.dart';
import 'package:opencode_mobile/core/push/computer_plugin.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/diagnostics/diagnostics_screen.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/features/push/push_providers.dart';
import 'package:opencode_mobile/features/update/update_providers.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fake_adapter.dart';

class _Connected extends ConnectionNotifier {
  _Connected(this.connection);

  final ActiveConnection connection;

  @override
  ActiveConnection? build() => connection;
}

void main() {
  testWidgets('shows each check and copies them as text', (tester) async {
    final adapter = FakeAdapter({
      '/api/health': FakeRoute.json({
        'healthy': true,
        'version': '2.1.0',
        'pid': 7,
      }),
      '/api/location': FakeRoute.json({'directory': '/home/me'}),
      '/api/mcp': FakeRoute.json({
        'data': [
          {
            'name': 'github',
            'status': {'status': 'connected'},
          },
          {
            'name': 'linear',
            'status': {'status': 'failed', 'error': 'token expired'},
          },
        ],
      }),
    });
    const server = ServerConfig(id: 'srv', baseUrl: 'http://pc.local:4096');
    final client = OpenCodeClient(
      baseUrl: server.baseUrl,
      username: 'opencode',
      password: 'pw',
      dio: fakeDio(adapter),
    );
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(
            () => _Connected(
              ActiveConnection(
                server: server,
                client: client,
                health: const ServerHealth(version: '2.1.0', pid: 7),
              ),
            ),
          ),
          serverEventStreamProvider.overrideWith((ref, _) => null),
          computerPluginProvider.overrideWith(
            (ref, id) async => const ComputerPluginCheck(
              ComputerPluginStatus.active,
              version: '0.2.0',
              latestVersion: '0.3.0',
              updateTarget: 'opencode-mobile-push',
            ),
          ),
          packageInfoProvider.overrideWithValue(
            Future.value(
              PackageInfo(
                appName: 'OpenCode Mobile',
                packageName: 'app.opencodemobile',
                version: '1.0.0',
                buildNumber: '5',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiagnosticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://pc.local:4096'), findsOneWidget);
    expect(find.textContaining('OpenCode 2.1.0'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('github'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Failed: token expired'), findsOneWidget);
    // The push plugin sits with the server; the app's own details live in
    // settings.
    expect(
      tester.getTopLeft(find.text('Push notification plugin')).dy,
      lessThan(tester.getTopLeft(find.text('Live updates')).dy),
    );
    // The installed version, and OpenCode's update when a newer one is out.
    expect(find.textContaining('Version 0.2.0'), findsOneWidget);
    expect(find.text('Version 0.3.0 is available'), findsOneWidget);
    expect(find.byKey(const Key('push-plugin-update')), findsOneWidget);
    expect(find.text('Address'), findsNothing);
    expect(find.text('1.0.0 (5)'), findsNothing);

    await tester.tap(find.byKey(const Key('diagnostics-copy')));
    await tester.pumpAndSettle();
    expect(clipboard, contains('[Server]\nAddress: http://pc.local:4096'));
    expect(clipboard, contains('linear: Failed: token expired'));
  });
}
