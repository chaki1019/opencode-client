import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/ads/ad_widgets.dart';
import 'package:opencode_mobile/features/ads/ads_providers.dart';
import 'package:opencode_mobile/features/ads/ads_service.dart';
import 'package:opencode_mobile/features/ads/ads_settings_section.dart';
import 'package:opencode_mobile/features/config/remote_values.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

import '../../support/fake_remote_settings.dart';

class FakeAdsService implements AdsService {
  RewardOutcome outcome = RewardOutcome.earned;
  int rewardedShown = 0;

  @override
  bool get available => true;

  @override
  final ValueListenable<bool> ready = ValueNotifier(true);

  @override
  Future<void> start() async {}

  @override
  Widget banner() => const SizedBox(key: Key('fake-banner'), height: 50);

  @override
  Future<RewardOutcome> showRewarded() async {
    rewardedShown++;
    return outcome;
  }

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

/// Remote Config as the console would serve it: ten free a day, ten more
/// per ad.
const tenAndTen = {
  'rewarded_ads_enabled': 'true',
  'daily_free_messages': '10',
  'ads_messages_per_reward': '10',
};

void main() {
  late FakeAdsService ads;
  late FakeRemoteSettings remote;
  late DateTime now;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ads = FakeAdsService();
    remote = FakeRemoteSettings(tenAndTen);
    now = DateTime(2026, 10, 3, 9);
  });

  /// Pumps a page with a send button that goes through [admitMessage] and
  /// counts every admitted message, as the composer does.
  Future<(ProviderContainer, List<bool>)> pumpGate(
    WidgetTester tester, {
    Widget? extra,
  }) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    final results = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsServiceProvider.overrideWithValue(ads),
          remoteSettingsProvider.overrideWithValue(remote),
          adsClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: const AdBanner(),
            body: Consumer(
              builder: (context, ref, _) => ListView(
                children: [
                  TextButton(
                    key: const Key('send'),
                    onPressed: () async {
                      final ok = await admitMessage(context, ref);
                      if (ok) {
                        await ref
                            .read(messageQuotaProvider.notifier)
                            .recordSent();
                      }
                      results.add(ok);
                    },
                    child: const Text('send'),
                  ),
                  ?extra,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    return (container, results);
  }

  Future<void> send(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('send')));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('ten messages a day go through without an ad', (tester) async {
    final (container, results) = await pumpGate(tester);
    expect(find.byKey(const Key('fake-banner')), findsOneWidget);

    await send(tester, 10);
    expect(results, List.filled(10, true));
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(messageQuotaProvider).remaining, 0);
  });

  testWidgets('watching the ad sends and adds ten more for today', (
    tester,
  ) async {
    final (container, results) = await pumpGate(tester);
    await send(tester, 10);

    await send(tester);
    expect(find.text('今日の無料送信回数を使い切りました'), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-reward')));
    await tester.pumpAndSettle();
    expect(ads.rewardedShown, 1);
    expect(results.last, isTrue);
    expect(container.read(messageQuotaProvider).remaining, 9);

    await send(tester, 9);
    expect(ads.rewardedShown, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('closing the ad early or cancelling keeps the message', (
    tester,
  ) async {
    final (container, results) = await pumpGate(tester);
    await send(tester, 10);

    ads.outcome = RewardOutcome.skipped;
    await send(tester);
    await tester.tap(find.byKey(const Key('watch-reward')));
    await tester.pumpAndSettle();
    expect(results.last, isFalse);
    expect(find.text('広告を最後まで見ると送信できます。'), findsOneWidget);

    await send(tester);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(results.last, isFalse);
    expect(container.read(messageQuotaProvider).sent, 10);
  });

  testWidgets('an ad that cannot load does not block sending', (tester) async {
    final (_, results) = await pumpGate(tester);
    await send(tester, 10);

    ads.outcome = RewardOutcome.unavailable;
    await send(tester);
    await tester.tap(find.byKey(const Key('watch-reward')));
    await tester.pumpAndSettle();
    expect(results.last, isTrue);
  });

  testWidgets('the count starts over on the next day', (tester) async {
    final (container, _) = await pumpGate(tester);
    await send(tester, 10);

    now = DateTime(2026, 10, 4, 0, 5);
    await send(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(messageQuotaProvider).day, '2026-10-04');
    expect(container.read(messageQuotaProvider).remaining, 9);
  });

  testWidgets('after removing ads there is no banner and no ad to watch', (
    tester,
  ) async {
    final (container, results) = await pumpGate(tester);
    await container.read(adsRemovedProvider.notifier).markRemoved();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-banner')), findsNothing);

    await send(tester, 12);
    expect(results, List.filled(12, true));
    expect(ads.rewardedShown, 0);
  });

  testWidgets('settings show what is left today', (tester) async {
    await pumpGate(
      tester,
      extra: AdsSettingsSection(header: (title) => Text(title)),
    );
    expect(find.text('広告'), findsOneWidget);
    expect(find.text('残り10回'), findsOneWidget);
    // The purchase stays hidden until the store has the product.
    expect(find.byKey(const Key('remove-ads')), findsNothing);

    await send(tester, 3);
    expect(find.text('残り7回'), findsOneWidget);
  });

  testWidgets('with rewarded ads switched off, sending is never limited', (
    tester,
  ) async {
    remote = FakeRemoteSettings({
      ...tenAndTen,
      'rewarded_ads_enabled': 'false',
    });
    final (_, results) = await pumpGate(
      tester,
      extra: AdsSettingsSection(header: (title) => Text(title)),
    );
    // The banner stays; only the limit and its row go.
    expect(find.byKey(const Key('fake-banner')), findsOneWidget);
    expect(find.byKey(const Key('ads-free-left')), findsNothing);

    await send(tester, 12);
    expect(results, List.filled(12, true));
    expect(find.byType(AlertDialog), findsNothing);
    expect(ads.rewardedShown, 0);
  });

  testWidgets('Remote Config sets the counts', (tester) async {
    remote = FakeRemoteSettings({
      ...tenAndTen,
      'daily_free_messages': '3',
      'ads_messages_per_reward': '5',
    });
    final (container, _) = await pumpGate(tester);
    await send(tester, 3);
    expect(find.byType(AlertDialog), findsNothing);

    await send(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('watch-reward')));
    await tester.pumpAndSettle();
    expect(container.read(messageQuotaProvider).remaining, 4);
  });

  testWidgets('a console change applies while the app runs', (tester) async {
    final (_, results) = await pumpGate(tester);
    await send(tester, 10);
    expect(remote.refreshes, 1);

    remote.push({...tenAndTen, 'rewarded_ads_enabled': 'false'});
    await tester.pumpAndSettle();
    await send(tester);
    expect(results.last, isTrue);
    expect(find.byType(AlertDialog), findsNothing);

    remote.push(tenAndTen);
    await tester.pumpAndSettle();
    await send(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('nothing fetched yet means no limit', (tester) async {
    remote = FakeRemoteSettings();
    final (_, results) = await pumpGate(tester);
    await send(tester, 12);
    expect(results, List.filled(12, true));
    expect(ads.rewardedShown, 0);
  });
}
