/// The rewarded-ad settings from Remote Config (docs/ads.md). The defaults
/// live in the Remote Config console, not in the app.
class AdsPolicy {
  const AdsPolicy({
    required this.rewarded,
    required this.dailyFreeMessages,
    required this.messagesPerReward,
  });

  /// No daily limit and no rewarded ad.
  static const off = AdsPolicy(
    rewarded: false,
    dailyFreeMessages: 0,
    messagesPerReward: 0,
  );

  /// Whether the daily limit and its rewarded ad apply. Off means messages
  /// are never limited; banners are not affected.
  final bool rewarded;

  /// Messages a day that need no ad.
  final int dailyFreeMessages;

  /// Messages one rewarded ad adds for the rest of the day.
  final int messagesPerReward;

  /// The `ads` entry of [remoteSettingsJson]. The limit applies only when
  /// it is switched on and both counts are valid; anything less (nothing
  /// fetched yet, a missing or out-of-range value) means [off], so a broken
  /// setting never locks anyone out.
  factory AdsPolicy.fromJson(Object? json) {
    final entry = json is Map ? json : const {};
    final daily = _count(entry['freeMessages']);
    final perReward = _count(entry['messagesPerReward']);
    if (entry['rewarded'] != true || daily == null || perReward == null) {
      return off;
    }
    return AdsPolicy(
      rewarded: true,
      dailyFreeMessages: daily,
      messagesPerReward: perReward,
    );
  }

  static int? _count(Object? value) =>
      value is int && value >= 1 && value <= 1000 ? value : null;

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
