import 'package:flutter/foundation.dart';

/// Build-time ad settings, passed with `--dart-define-from-file=ads.env.json`
/// (see docs/ads.md). A build without them shows Google's test ads, so
/// development never serves live ads.
class AdsConfig {
  const AdsConfig({
    this.androidBannerId = _testAndroidBanner,
    this.androidRewardedId = _testAndroidRewarded,
    this.iosBannerId = _testIosBanner,
    this.iosRewardedId = _testIosRewarded,
    this.removeAdsEnabled = false,
    this.removeAdsProductId = 'remove_ads',
    this.dailyFreeMessages = 10,
    this.messagesPerReward = 10,
  });

  const AdsConfig.fromEnvironment()
    : androidBannerId = const String.fromEnvironment(
        'ADMOB_ANDROID_BANNER_ID',
        defaultValue: _testAndroidBanner,
      ),
      androidRewardedId = const String.fromEnvironment(
        'ADMOB_ANDROID_REWARDED_ID',
        defaultValue: _testAndroidRewarded,
      ),
      iosBannerId = const String.fromEnvironment(
        'ADMOB_IOS_BANNER_ID',
        defaultValue: _testIosBanner,
      ),
      iosRewardedId = const String.fromEnvironment(
        'ADMOB_IOS_REWARDED_ID',
        defaultValue: _testIosRewarded,
      ),
      // Off until the product exists in App Store Connect and Play Console.
      removeAdsEnabled = const bool.fromEnvironment('REMOVE_ADS_ENABLED'),
      removeAdsProductId = const String.fromEnvironment(
        'REMOVE_ADS_PRODUCT_ID',
        defaultValue: 'remove_ads',
      ),
      dailyFreeMessages = 10,
      messagesPerReward = 10;

  // Google's sample ad units: https://developers.google.com/admob/flutter/test-ads
  static const _testAndroidBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testIosBanner = 'ca-app-pub-3940256099942544/2435281174';
  static const _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  final String androidBannerId;
  final String androidRewardedId;
  final String iosBannerId;
  final String iosRewardedId;

  /// Whether the "remove ads" purchase is offered.
  final bool removeAdsEnabled;

  /// The non-consumable product, with the same ID in both stores.
  final String removeAdsProductId;

  /// Messages a day that need no ad.
  final int dailyFreeMessages;

  /// Messages one rewarded ad adds for the rest of the day.
  final int messagesPerReward;

  String get bannerId => defaultTargetPlatform == TargetPlatform.iOS
      ? iosBannerId
      : androidBannerId;

  String get rewardedId => defaultTargetPlatform == TargetPlatform.iOS
      ? iosRewardedId
      : androidRewardedId;
}
