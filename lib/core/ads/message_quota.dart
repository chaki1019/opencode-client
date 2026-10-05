import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Messages sent today against today's allowance. The allowance starts at
/// the free count and grows with each rewarded ad; both reset when the
/// local date moves forward, at midnight in the phone's time zone.
class MessageQuota {
  const MessageQuota({
    required this.day,
    required this.sent,
    required this.allowance,
  });

  /// The local date as `yyyy-mm-dd`.
  final String day;
  final int sent;
  final int allowance;

  int get remaining => allowance - sent < 0 ? 0 : allowance - sent;

  static String dayOf(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }

  /// This quota, or a fresh one once [now]'s date is past it. A clock set
  /// back keeps the quota as it is, so winding it to 23:59 and letting it
  /// pass midnight again earns nothing; a clock set ahead spends the days
  /// it skips. A free count raised during the day applies at once; a
  /// lowered one waits for the next day, so nobody loses messages they
  /// were promised.
  MessageQuota on(DateTime now, {required int freeMessages}) {
    final today = dayOf(now);
    // `yyyy-mm-dd` sorts by date; an empty day (nothing stored) sorts first.
    if (today.compareTo(day) > 0) {
      return MessageQuota(day: today, sent: 0, allowance: freeMessages);
    }
    return allowance < freeMessages ? withAllowance(freeMessages) : this;
  }

  MessageQuota withSent(int sent) =>
      MessageQuota(day: day, sent: sent, allowance: allowance);

  MessageQuota withAllowance(int allowance) =>
      MessageQuota(day: day, sent: sent, allowance: allowance);
}

/// Keeps the quota and the ad-free purchase next to the other stored data.
class AdsStore {
  AdsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _quotaKey = 'ads.quota.v1';
  static const _removedKey = 'ads.removed.v1';

  final FlutterSecureStorage _storage;

  Future<MessageQuota?> loadQuota() async {
    final raw = await _storage.read(key: _quotaKey);
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return MessageQuota(
      day: json['day'] as String,
      sent: json['sent'] as int,
      allowance: json['allowance'] as int,
    );
  }

  Future<void> saveQuota(MessageQuota quota) => _storage.write(
    key: _quotaKey,
    value: jsonEncode({
      'day': quota.day,
      'sent': quota.sent,
      'allowance': quota.allowance,
    }),
  );

  Future<bool> loadRemoved() async =>
      await _storage.read(key: _removedKey) == 'true';

  Future<void> saveRemoved(bool removed) =>
      _storage.write(key: _removedKey, value: '$removed');
}
