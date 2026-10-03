import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opencode_mobile/app/router.dart';
import 'package:opencode_mobile/core/storage/settings_store.dart';
import 'package:opencode_mobile/main.dart';

import '../../support/fake_discovery.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: noDiscoveryOverrides,
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
}
