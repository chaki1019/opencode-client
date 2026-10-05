import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:opencode_mobile/app/router.dart';
import 'package:opencode_mobile/core/analytics/usage_analytics.dart';
import 'package:opencode_mobile/core/crash/crash_reporter.dart';
import 'package:opencode_mobile/core/storage/settings_store.dart';
import 'package:opencode_mobile/core/support/support_config.dart';
import 'package:opencode_mobile/features/settings/settings_providers.dart';
import 'package:opencode_mobile/features/settings/support_section.dart';
import 'package:opencode_mobile/features/update/update_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_discovery.dart';

class _FakeCrashReporter implements CrashReporter {
  final calls = <bool>[];

  @override
  bool get available => true;

  @override
  Future<void> setEnabled(bool on) async => calls.add(on);
}

class _FakeUsageAnalytics implements UsageAnalytics {
  final calls = <bool>[];

  @override
  bool get available => true;

  @override
  NavigatorObserver? get observer => null;

  @override
  Future<void> setEnabled(bool on) async => calls.add(on);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...noDiscoveryOverrides, ...overrides],
        child: const OpenCodeMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OpenCodeMobileApp)),
    );
    // Settings open without a server.
    container.read(routerProvider).push('/settings');
    await tester.pumpAndSettle();
    return container;
  }

  ThemeMode themeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testWidgets('appearance and language apply at once and are kept', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.text('外観'), findsOneWidget);
    expect(themeMode(tester), ThemeMode.system);

    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pumpAndSettle();
    expect(themeMode(tester), ThemeMode.dark);

    // The device is Japanese; choosing English switches the app over.
    await tester.tap(find.byKey(const Key('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    final stored = await SettingsStore().load();
    expect(stored.themeMode, ThemeMode.dark);
    expect(stored.languageCode, 'en');

    await tester.tap(find.byKey(const Key('language-system')));
    await tester.pumpAndSettle();
    expect(find.text('外観'), findsOneWidget);
    expect((await SettingsStore().load()).languageCode, isNull);
  });

  testWidgets('haptics are on by default and can be turned off', (
    tester,
  ) async {
    await pumpSettings(tester);
    final toggle = find.byKey(const Key('haptics'));
    await tester.scrollUntilVisible(toggle, 100);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect((await SettingsStore().load()).haptics, isFalse);
  });

  testWidgets('support rows are hidden when the build has none', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      overrides: [
        supportConfigProvider.overrideWithValue(const SupportConfig()),
      ],
    );
    expect(find.text('サポートとプライバシー'), findsNothing);
  });

  testWidgets('support rows show and crash reports can be turned off', (
    tester,
  ) async {
    final reporter = _FakeCrashReporter();
    await pumpSettings(
      tester,
      overrides: [
        crashReporterProvider.overrideWithValue(reporter),
        supportConfigProvider.overrideWithValue(
          const SupportConfig(
            email: 'help@example.com',
            siteUrl: 'https://example.pages.dev',
          ),
        ),
      ],
    );
    final toggle = find.byKey(const Key('crash-reports'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact')), findsOneWidget);
    expect(find.text('help@example.com'), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(reporter.calls, [false]);
    expect((await SettingsStore().load()).crashReports, isFalse);
  });

  testWidgets('usage statistics can be turned off', (tester) async {
    final analytics = _FakeUsageAnalytics();
    await pumpSettings(
      tester,
      overrides: [
        usageAnalyticsProvider.overrideWithValue(analytics),
        supportConfigProvider.overrideWithValue(const SupportConfig()),
      ],
    );
    final toggle = find.byKey(const Key('usage-analytics'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(find.text('利用状況を送信'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(analytics.calls, [false]);
    expect((await SettingsStore().load()).usageAnalytics, isFalse);
  });

  testWidgets('stored settings are applied on start', (tester) async {
    await SettingsStore().save(
      const AppSettings(themeMode: ThemeMode.light, languageCode: 'en'),
    );
    await pumpSettings(tester);
    expect(themeMode(tester), ThemeMode.light);
    expect(find.text('Appearance'), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
          .groupValue,
      ThemeMode.light,
    );
  });

  testWidgets('back from settings returns to the connect screen', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('OpenCode サーバーに接続'), findsOneWidget);
    expect(GoRouter.maybeOf(tester.element(find.byType(Scaffold))), isNotNull);
  });

  testWidgets('shows the app version and OS', (tester) async {
    await pumpSettings(
      tester,
      overrides: [
        packageInfoProvider.overrideWithValue(
          Future.value(
            PackageInfo(
              appName: 'OpenCode Mobile',
              packageName: 'app.opencodemobile',
              version: '1.2.0',
              buildNumber: '7',
            ),
          ),
        ),
      ],
    );
    final version = find.byKey(const Key('app-version'));
    await tester.scrollUntilVisible(find.byKey(const Key('app-os')), 100);
    expect(
      find.descendant(of: version, matching: find.text('1.2.0 (7)')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-os')), findsOneWidget);
  });
}
