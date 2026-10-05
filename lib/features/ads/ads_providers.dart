import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_config.dart';
import '../../core/ads/ads_policy.dart';
import '../../core/ads/message_quota.dart';
import 'ads_service.dart';

/// Overridden in tests; real builds read `--dart-define`s.
final adsConfigProvider = Provider<AdsConfig>(
  (ref) => const AdsConfig.fromEnvironment(),
);

final adsStoreProvider = Provider<AdsStore>((ref) => AdsStore());

/// Android and iOS, the platforms AdMob and the stores support.
bool get isAdsPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

final adsServiceProvider = Provider<AdsService>(
  (ref) => isAdsPlatform
      ? GoogleAdsService(ref.watch(adsConfigProvider))
      : NoAdsService(),
);

/// The quota's notion of now, so tests can move to the next day.
final adsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether the user bought "remove ads"; null until storage is read, so a
/// buyer never sees a banner flash in.
class AdsRemovedNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    ref.read(adsStoreProvider).loadRemoved().then((removed) {
      if (ref.mounted && state == null) state = removed;
    });
    return null;
  }

  Future<void> markRemoved() async {
    state = true;
    await ref.read(adsStoreProvider).saveRemoved(true);
  }
}

final adsRemovedProvider = NotifierProvider<AdsRemovedNotifier, bool?>(
  AdsRemovedNotifier.new,
);

/// Whether this build shows ads to this user right now.
final adsActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(adsServiceProvider).available &&
      ref.watch(adsRemovedProvider) == false,
);

/// Starts the ad SDK (and its consent prompt) once it is known that the
/// user sees ads. Watched by the app root.
final adsStartupProvider = Provider<void>((ref) {
  if (ref.watch(adsActiveProvider)) {
    unawaited(ref.read(adsServiceProvider).start());
  }
});

/// The rewarded-ad switches in force: the server's latest, else the last
/// one stored, else the build's own. Fed by the update check, which reads
/// the same response.
class AdsPolicyNotifier extends Notifier<AdsPolicy> {
  AdsPolicy get _fallback => ref.read(adsConfigProvider).defaultPolicy;
  AdsStore get _store => ref.read(adsStoreProvider);

  /// Set once the server answered, so a slow stored read does not
  /// overwrite it.
  bool _received = false;

  @override
  AdsPolicy build() {
    _store.loadPolicy(_fallback).then((stored) {
      if (!_received && stored != null && ref.mounted) state = stored;
    });
    return _fallback;
  }

  /// Applies the `ads` entry of a `/v1/app-version` response. A response
  /// without one (a relay from before the switches) means the build's own
  /// values.
  Future<void> apply(Object? response) async {
    if (response is! Map) return;
    _received = true;
    final policy = AdsPolicy.fromJson(response['ads'], _fallback);
    if (policy == state) return;
    state = policy;
    await _store.savePolicy(policy);
  }
}

final adsPolicyProvider = NotifierProvider<AdsPolicyNotifier, AdsPolicy>(
  AdsPolicyNotifier.new,
);

/// Whether sending is limited per day, with a rewarded ad for more.
final rewardedActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(adsActiveProvider) && ref.watch(adsPolicyProvider).rewarded,
);

/// Today's messages against today's allowance.
class MessageQuotaNotifier extends Notifier<MessageQuota> {
  AdsPolicy get _policy => ref.read(adsPolicyProvider);
  AdsStore get _store => ref.read(adsStoreProvider);

  /// Set once something is counted, so a slow initial read does not
  /// overwrite it.
  bool _changed = false;

  @override
  MessageQuota build() {
    _store.loadQuota().then((stored) {
      if (!_changed && stored != null && ref.mounted) state = stored;
    });
    return _fresh();
  }

  MessageQuota _fresh() => const MessageQuota(
    day: '',
    sent: 0,
    allowance: 0,
  ).on(ref.read(adsClockProvider)(), freeMessages: _policy.dailyFreeMessages);

  /// The quota for today, rolled over if the date changed since.
  MessageQuota get today => state.on(
    ref.read(adsClockProvider)(),
    freeMessages: _policy.dailyFreeMessages,
  );

  Future<void> recordSent() {
    final quota = today;
    return _update(quota.withSent(quota.sent + 1));
  }

  /// Adds one rewarded ad's worth of messages on top of what is sent.
  Future<void> addReward() {
    final quota = today;
    return _update(
      quota.withAllowance(
        max(quota.allowance, quota.sent) + _policy.messagesPerReward,
      ),
    );
  }

  Future<void> _update(MessageQuota quota) async {
    _changed = true;
    state = quota;
    await _store.saveQuota(quota);
  }
}

final messageQuotaProvider =
    NotifierProvider<MessageQuotaNotifier, MessageQuota>(
      MessageQuotaNotifier.new,
    );
