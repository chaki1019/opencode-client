import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
