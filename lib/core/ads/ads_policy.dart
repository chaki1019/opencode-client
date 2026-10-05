/// The rewarded-ad switches Remote Config can change without a new build
/// (docs/ads.md).
class AdsPolicy {
  const AdsPolicy({
    required this.rewarded,
    required this.dailyFreeMessages,
    required this.messagesPerReward,
  });

  /// Whether the daily limit and its rewarded ad apply. Off means messages
  /// are never limited; banners are not affected.
  final bool rewarded;

  /// Messages a day that need no ad.
  final int dailyFreeMessages;

  /// Messages one rewarded ad adds for the rest of the day.
  final int messagesPerReward;

  /// The `ads` entry of [remoteSettingsJson] over [fallback] (the build's
  /// own values).
  /// A missing, null or out-of-range field keeps the fallback's, so a
  /// mistyped variable never changes anything.
  factory AdsPolicy.fromJson(Object? json, AdsPolicy fallback) {
    final entry = json is Map ? json : const {};
    final rewarded = entry['rewarded'];
    return AdsPolicy(
      rewarded: rewarded is bool ? rewarded : fallback.rewarded,
      dailyFreeMessages: _count(
        entry['freeMessages'],
        fallback.dailyFreeMessages,
      ),
      messagesPerReward: _count(
        entry['messagesPerReward'],
        fallback.messagesPerReward,
      ),
    );
  }

  static int _count(Object? value, int fallback) =>
      value is int && value >= 1 && value <= 1000 ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is AdsPolicy &&
      other.rewarded == rewarded &&
      other.dailyFreeMessages == dailyFreeMessages &&
      other.messagesPerReward == messagesPerReward;

  @override
  int get hashCode =>
      Object.hash(rewarded, dailyFreeMessages, messagesPerReward);
}
