import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Today's messages: the daily free ones, which reset when the local date
/// moves forward (midnight in the phone's time zone), and those earned by
/// watching rewarded ads, which carry over to later days until used.
class MessageQuota {
  const MessageQuota({
    required this.day,
    required this.sent,
    required this.free,
    this.earned = 0,
    this.earnedSent = 0,
  });

  /// The local date as `yyyy-mm-dd`.
  final String day;

  /// Free messages used today.
  final int sent;

  /// Free messages for today.
  final int free;

  /// Messages earned from ads and not used yet.
  final int earned;

  /// Earned messages used today.
  final int earnedSent;

  int get freeLeft => free - sent < 0 ? 0 : free - sent;

  int get remaining => freeLeft + earned;

  /// Every message sent today.
  int get sentToday => sent + earnedSent;

  /// Earned messages available today, used or not.
  int get earnedToday => earnedSent + earned;

  /// Every message available today: the free ones and the earned ones.
  int get allowance => free + earnedToday;

  static String dayOf(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }

  /// This quota, or a fresh day once [now]'s date is past it, keeping up to
  /// [carryOver] earned messages. A clock set back keeps the quota as it
  /// is, so winding it to 23:59 and letting it pass midnight again earns
  /// nothing; a clock set ahead spends the days it skips. A free count
  /// raised during the day applies at once; a lowered one waits for the
  /// next day, so nobody loses messages they were promised.
  MessageQuota on(
    DateTime now, {
    required int freeMessages,
    required int carryOver,
  }) {
    final today = dayOf(now);
    // `yyyy-mm-dd` sorts by date; an empty day (nothing stored) sorts first.
    if (today.compareTo(day) > 0) {
      return MessageQuota(
        day: today,
        sent: 0,
        free: freeMessages,
        earned: earned < carryOver ? earned : carryOver,
      );
    }
    return free < freeMessages ? _copy(free: freeMessages) : this;
  }

  /// Uses one message: a free one while any are left, then an earned one.
  MessageQuota spend() => freeLeft > 0
      ? _copy(sent: sent + 1)
      : earned > 0
      ? _copy(earned: earned - 1, earnedSent: earnedSent + 1)
      : this;

  MessageQuota earn(int messages) => _copy(earned: earned + messages);

  MessageQuota _copy({int? sent, int? free, int? earned, int? earnedSent}) =>
      MessageQuota(
        day: day,
        sent: sent ?? this.sent,
        free: free ?? this.free,
        earned: earned ?? this.earned,
        earnedSent: earnedSent ?? this.earnedSent,
      );
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
      // Builds before carry-over stored one allowance with ads included;
      // that day ends without anything to carry.
      free: (json['free'] ?? json['allowance']) as int,
      earned: (json['earned'] as int?) ?? 0,
      earnedSent: (json['earnedSent'] as int?) ?? 0,
    );
  }

  Future<void> saveQuota(MessageQuota quota) => _storage.write(
    key: _quotaKey,
    value: jsonEncode({
      'day': quota.day,
      'sent': quota.sent,
      'free': quota.free,
      'earned': quota.earned,
      'earnedSent': quota.earnedSent,
    }),
  );

  Future<bool> loadRemoved() async =>
      await _storage.read(key: _removedKey) == 'true';

  Future<void> saveRemoved(bool removed) =>
      _storage.write(key: _removedKey, value: '$removed');
}
