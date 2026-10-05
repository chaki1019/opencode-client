import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_config.dart';
import '../../core/ads/ads_policy.dart';
import '../../core/ads/message_quota.dart';
import '../../core/ads/quota_reminder.dart';
import '../../core/config/remote_settings.dart';
import '../../l10n/app_localizations.dart';
import '../config/remote_values.dart';
import '../settings/settings_providers.dart';
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

/// The rewarded-ad settings in force, from Remote Config.
final adsPolicyProvider = Provider<AdsPolicy>(
  (ref) => AdsPolicy.fromJson(
    remoteSettingsJson(ref.watch(remoteValuesProvider))['ads'],
  ),
);

/// Whether sending is limited per day, with a rewarded ad for more.
final rewardedActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(adsActiveProvider) && ref.watch(adsPolicyProvider).rewarded,
);

/// Today's free messages and the earned ones carried over.
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

  MessageQuota _fresh() =>
      _rolled(const MessageQuota(day: '', sent: 0, free: 0));

  MessageQuota _rolled(MessageQuota quota) => quota.on(
    ref.read(adsClockProvider)(),
    freeMessages: _policy.dailyFreeMessages,
    carryOver: _policy.carryOver,
  );

  /// The quota for today, rolled over if the date changed since.
  MessageQuota get today => _rolled(state);

  Future<void> recordSent() async {
    await _update(today.spend());
    await remindIfUsed();
  }

  /// Sets the midnight reminder once a regular message was used today, so
  /// days without any use pass quietly.
  Future<void> remindIfUsed() async {
    if (today.sent == 0 || !ref.read(rewardedActiveProvider)) return;
    final on =
        ref.read(quotaReminderOnProvider) ??
        await ref.read(adsStoreProvider).loadReminder();
    if (!on) return;
    final now = ref.read(adsClockProvider)();
    final code = ref.read(settingsProvider).languageCode;
    final l10n = lookupAppLocalizations(
      code != null ? Locale(code) : _deviceLocale(),
    );
    await ref
        .read(quotaReminderProvider)
        .remindAt(
          DateTime(now.year, now.month, now.day + 1),
          title: l10n.quotaReminderTitle,
          body: l10n.quotaReminderBody(_policy.dailyFreeMessages),
          channelName: l10n.quotaReminderChannel,
        );
  }

  /// Adds one rewarded ad's worth of messages, kept until used.
  Future<void> addReward() => _update(today.earn(_policy.messagesPerReward));

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

Locale _deviceLocale() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final locale = dispatcher.locales.firstOrNull ?? dispatcher.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      )
      ? Locale(locale.languageCode)
      : const Locale('en');
}

/// Schedules the local notification that the day's messages are back.
final quotaReminderProvider = Provider<QuotaReminder>(
  (ref) => isAdsPlatform ? LocalQuotaReminder() : const QuotaReminder.none(),
);

/// Whether the midnight reminder is on; null until storage is read.
class QuotaReminderOnNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    ref.read(adsStoreProvider).loadReminder().then((on) {
      if (ref.mounted && state == null) state = on;
    });
    return null;
  }

  /// Turning it on asks for notification permission and sets today's
  /// reminder if messages were already used; off cancels it.
  Future<void> set(bool on) async {
    state = on;
    await ref.read(adsStoreProvider).saveReminder(on);
    final reminder = ref.read(quotaReminderProvider);
    if (on) {
      await reminder.requestPermission();
      await ref.read(messageQuotaProvider.notifier).remindIfUsed();
    } else {
      await reminder.cancel();
    }
  }
}

final quotaReminderOnProvider =
    NotifierProvider<QuotaReminderOnNotifier, bool?>(
      QuotaReminderOnNotifier.new,
    );
