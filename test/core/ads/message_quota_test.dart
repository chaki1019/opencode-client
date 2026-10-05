import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/ads/ads_policy.dart';
import 'package:opencode_mobile/core/ads/message_quota.dart';

void main() {
  test('a quota carries over within the day and resets on the next', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 12, allowance: 20);
    expect(quota.remaining, 8);

    final later = quota.on(DateTime(2026, 10, 3, 23, 59), freeMessages: 10);
    expect(identical(later, quota), isTrue);

    final tomorrow = quota.on(DateTime(2026, 10, 4, 0, 1), freeMessages: 10);
    expect(tomorrow.day, '2026-10-04');
    expect(tomorrow.sent, 0);
    expect(tomorrow.remaining, 10);
  });

  test('remaining never goes below zero', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 11, allowance: 10);
    expect(quota.remaining, 0);
  });

  test('the store keeps the quota and the purchase', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = AdsStore();
    expect(await store.loadQuota(), isNull);
    expect(await store.loadRemoved(), isFalse);

    await store.saveQuota(
      const MessageQuota(day: '2026-10-03', sent: 3, allowance: 20),
    );
    await store.saveRemoved(true);

    final quota = (await AdsStore().loadQuota())!;
    expect((quota.day, quota.sent, quota.allowance), ('2026-10-03', 3, 20));
    expect(await AdsStore().loadRemoved(), isTrue);
  });

  test('a raised free count applies today, a lowered one tomorrow', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 10, allowance: 10);
    final today = DateTime(2026, 10, 3, 12);
    expect(quota.on(today, freeMessages: 15).remaining, 5);
    expect(quota.on(today, freeMessages: 5).allowance, 10);
    final tomorrow = DateTime(2026, 10, 4, 12);
    expect(quota.on(tomorrow, freeMessages: 5).remaining, 5);
  });

  test('a policy keeps the fallback for anything unclear', () {
    const fallback = AdsPolicy(
      rewarded: true,
      dailyFreeMessages: 10,
      messagesPerReward: 10,
    );
    expect(AdsPolicy.fromJson(null, fallback), fallback);
    expect(
      AdsPolicy.fromJson({
        'rewarded': 'no',
        'freeMessages': 0,
        'messagesPerReward': 5000,
      }, fallback),
      fallback,
    );
    expect(
      AdsPolicy.fromJson({
        'rewarded': false,
        'freeMessages': 3,
        'messagesPerReward': null,
      }, fallback),
      const AdsPolicy(
        rewarded: false,
        dailyFreeMessages: 3,
        messagesPerReward: 10,
      ),
    );
  });
}
