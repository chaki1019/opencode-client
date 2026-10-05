import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/ads/ads_policy.dart';
import 'package:opencode_mobile/core/ads/message_quota.dart';
import 'package:opencode_mobile/core/config/remote_settings.dart';

void main() {
  MessageQuota at(
    MessageQuota quota,
    DateTime now, {
    int free = 10,
    int carryOver = 20,
  }) => quota.on(now, freeMessages: free, carryOver: carryOver);

  test('a quota carries over within the day and resets on the next', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 7, free: 10);
    expect(quota.remaining, 3);

    final later = at(quota, DateTime(2026, 10, 3, 23, 59));
    expect(identical(later, quota), isTrue);

    final tomorrow = at(quota, DateTime(2026, 10, 4, 0, 1));
    expect(tomorrow.day, '2026-10-04');
    expect(tomorrow.sent, 0);
    expect(tomorrow.remaining, 10);
  });

  test('regular messages go first, earned ones after', () {
    var quota = const MessageQuota(day: '2026-10-03', sent: 0, free: 2);
    quota = quota.earn(5);
    expect(quota.remaining, 7);
    quota = quota.spend().spend();
    expect((quota.freeLeft, quota.earned), (0, 5));
    quota = quota.spend();
    expect((quota.sent, quota.earned, quota.remaining), (2, 4, 4));
  });

  test('earned messages carry over to the next day, up to the limit', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 3, free: 5, earned: 7);
    final tomorrow = at(quota, DateTime(2026, 10, 4, 9), free: 5);
    expect((tomorrow.sent, tomorrow.earned, tomorrow.remaining), (0, 7, 12));

    const many = MessageQuota(day: '2026-10-03', sent: 5, free: 5, earned: 35);
    expect(at(many, DateTime(2026, 10, 4, 9)).earned, 20);
    // Within the day nothing is cut.
    expect(at(many, DateTime(2026, 10, 3, 23)).earned, 35);
    // Without a limit set, earned messages last only their day.
    expect(at(quota, DateTime(2026, 10, 4, 9), carryOver: 0).earned, 0);
  });

  test('setting the clock back never starts the count over', () {
    const quota = MessageQuota(day: '2026-10-04', sent: 10, free: 10);
    // Back to 23:59 the day before, then past midnight again.
    final back = at(quota, DateTime(2026, 10, 3, 23, 59));
    expect(back.remaining, 0);
    final again = at(back, DateTime(2026, 10, 4, 0, 0));
    expect(again.remaining, 0);

    // A clock run ahead spends that day: back at the real date, today's
    // count is the one already used.
    const ahead = MessageQuota(day: '2026-10-05', sent: 10, free: 10);
    expect(at(ahead, DateTime(2026, 10, 4, 9)).remaining, 0);
    expect(at(ahead, DateTime(2026, 10, 5, 9)).remaining, 0);
    expect(at(ahead, DateTime(2026, 10, 6, 0, 1)).remaining, 10);
  });

  test('remaining never goes below zero', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 11, free: 10);
    expect(quota.remaining, 0);
    expect(quota.spend().remaining, 0);
  });

  test('the store keeps the quota and the purchase', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = AdsStore();
    expect(await store.loadQuota(), isNull);
    expect(await store.loadRemoved(), isFalse);

    await store.saveQuota(
      const MessageQuota(day: '2026-10-03', sent: 3, free: 5, earned: 9),
    );
    await store.saveRemoved(true);

    final quota = (await AdsStore().loadQuota())!;
    expect(
      (quota.day, quota.sent, quota.free, quota.earned),
      ('2026-10-03', 3, 5, 9),
    );
    expect(await AdsStore().loadRemoved(), isTrue);
  });

  test('a quota stored before carry-over still reads', () async {
    FlutterSecureStorage.setMockInitialValues({
      'ads.quota.v1': '{"day":"2026-10-03","sent":4,"allowance":15}',
    });
    final quota = (await AdsStore().loadQuota())!;
    expect((quota.sent, quota.free, quota.earned), (4, 15, 0));
  });

  test('a raised free count applies today, a lowered one tomorrow', () {
    const quota = MessageQuota(day: '2026-10-03', sent: 10, free: 10);
    final today = DateTime(2026, 10, 3, 12);
    expect(at(quota, today, free: 15).remaining, 5);
    expect(at(quota, today, free: 5).free, 10);
    final tomorrow = DateTime(2026, 10, 4, 12);
    expect(at(quota, tomorrow, free: 5).remaining, 5);
  });

  test('a policy applies only when switched on with valid counts', () {
    expect(AdsPolicy.fromJson(null), AdsPolicy.off);
    expect(
      AdsPolicy.fromJson({
        'rewarded': true,
        'freeMessages': 5,
        'messagesPerReward': 5,
      }),
      const AdsPolicy(
        rewarded: true,
        dailyFreeMessages: 5,
        messagesPerReward: 5,
      ),
    );
    // The carry-over limit is optional: unset or broken means none.
    for (final (value, limit) in [(20, 20), (null, 0), (0, 0), ('20', 0)]) {
      expect(
        AdsPolicy.fromJson({
          'rewarded': true,
          'freeMessages': 5,
          'messagesPerReward': 5,
          'carryOver': value,
        }).carryOver,
        limit,
      );
    }
    for (final broken in [
      {'rewarded': false, 'freeMessages': 5, 'messagesPerReward': 5},
      {'rewarded': null, 'freeMessages': 5, 'messagesPerReward': 5},
      {'rewarded': true, 'freeMessages': 0, 'messagesPerReward': 5},
      {'rewarded': true, 'freeMessages': 5, 'messagesPerReward': 5000},
      {'rewarded': true, 'freeMessages': 5, 'messagesPerReward': null},
      {'rewarded': true, 'carryOver': 20},
    ]) {
      expect(AdsPolicy.fromJson(broken), AdsPolicy.off, reason: '$broken');
    }
  });

  test('Remote Config values read like the relay response', () {
    expect(remoteSettingsJson({}), {
      'ios': {'minimum': null},
      'android': {'minimum': null},
      'ads': {
        'rewarded': null,
        'freeMessages': null,
        'messagesPerReward': null,
        'carryOver': null,
      },
    });
    final json = remoteSettingsJson({
      'app_version': ' 1.2.0 ',
      'rewarded_ads_enabled': 'FALSE',
      'daily_free_messages': '20',
      'ads_messages_per_reward': 'ten',
      'ads_carryover_limit': '20',
    });
    expect(json['ios'], {'minimum': '1.2.0'});
    expect(json['android'], json['ios']);
    expect(remoteSettingsJson({'app_version': ''})['ios'], {'minimum': null});
    expect(json['ads'], {
      'rewarded': false,
      'freeMessages': 20,
      'messagesPerReward': null,
      'carryOver': 20,
    });
  });
}
