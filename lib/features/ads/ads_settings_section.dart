import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/message_quota.dart';
import '../../l10n/l10n.dart';
import '../chat/context_sheet.dart' show UsageRing;
import 'ads_providers.dart';
import 'ads_service.dart';
import 'remove_ads.dart';

/// Whether the user must be offered their ad consent again.
final _privacyOptionsProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!ref.watch(adsActiveProvider)) return false;
  return ref.watch(adsServiceProvider).privacyOptionsRequired();
});

/// The settings page's ad sections: today's messages with a rewarded ad to
/// earn more, then the "remove ads" purchase and the consent form. Empty
/// where the app shows no ads.
class AdsSettingsSection extends ConsumerWidget {
  const AdsSettingsSection({super.key, required this.header});

  /// Builds the section title in the settings page's style.
  final Widget Function(String title) header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(removeAdsProvider.select((s) => s.notice), (_, notice) {
      final text = switch (notice) {
        RemoveAdsNotice.purchased => l10n.removeAdsDone,
        RemoveAdsNotice.failed => l10n.purchaseFailed,
        null => null,
      };
      if (text != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    });

    final removed = ref.watch(adsRemovedProvider) == true;
    final active = ref.watch(adsActiveProvider);
    if (!removed && !active) return const SizedBox.shrink();

    final config = ref.watch(adsConfigProvider);
    final purchase = ref.watch(removeAdsProvider);
    final product = purchase.product;
    final privacy = ref.watch(_privacyOptionsProvider).value ?? false;
    final rewarded = !removed && ref.watch(rewardedActiveProvider);
    final adRows = [
      if (removed)
        ListTile(
          key: const Key('ads-removed'),
          leading: const Icon(Icons.check_circle_outline),
          title: Text(l10n.removeAdsDone),
        )
      else ...[
        if (config.removeAdsEnabled && product != null)
          ListTile(
            key: const Key('remove-ads'),
            title: Text(l10n.removeAds),
            subtitle: Text(l10n.removeAdsSubtitle),
            trailing: purchase.busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(product.price),
            onTap: purchase.busy
                ? null
                : () => ref.read(removeAdsProvider.notifier).buy(),
          ),
        if (config.removeAdsEnabled)
          ListTile(
            key: const Key('restore-purchases'),
            title: Text(l10n.restorePurchases),
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.restoreStarted)));
              ref.read(removeAdsProvider.notifier).restore();
            },
          ),
        if (privacy)
          ListTile(
            key: const Key('ad-privacy'),
            title: Text(l10n.adPrivacy),
            onTap: () => ref.read(adsServiceProvider).showPrivacyOptions(),
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rewarded) ...[
          header(l10n.settingsMessages),
          const MessageCountTile(),
          const EarnMessagesTile(),
        ],
        if (adRows.isNotEmpty) ...[header(l10n.settingsAds), ...adRows],
      ],
    );
  }
}

/// How much of today's messages, free and earned, is used: full only when
/// none are left.
double quotaRingFraction(MessageQuota quota) => quota.allowance == 0
    ? 1.0
    : (quota.sentToday / quota.allowance).clamp(0.0, 1.0);

/// Today's messages sent against all available, as a ring and a count,
/// with the part earned from ads.
class MessageCountTile extends ConsumerWidget {
  const MessageCountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(messageQuotaProvider);
    final quota = ref.read(messageQuotaProvider.notifier).today;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ListTile(
      key: const Key('messages-today'),
      leading: UsageRing(
        fraction: quotaRingFraction(quota),
        // Icon-sized, so the titles line up with the row below.
        size: 24,
        strokeWidth: 3.5,
        color: quota.remaining == 0 ? scheme.error : scheme.primary,
        trackColor: scheme.outlineVariant,
      ),
      title: Text(l10n.messagesToday),
      subtitle: Text(
        quota.earnedToday == 0
            ? l10n.messagesTodayValue(quota.sentToday, quota.allowance)
            : l10n.messagesTodayEarned(
                quota.sentToday,
                quota.allowance,
                quota.earnedToday,
              ),
      ),
    );
  }
}

/// Watches a rewarded ad on request, before the day's messages run out.
class EarnMessagesTile extends ConsumerStatefulWidget {
  const EarnMessagesTile({super.key});

  @override
  ConsumerState<EarnMessagesTile> createState() => _EarnMessagesTileState();
}

class _EarnMessagesTileState extends ConsumerState<EarnMessagesTile> {
  bool _loading = false;

  Future<void> _watch() async {
    setState(() => _loading = true);
    final outcome = await ref.read(adsServiceProvider).showRewarded();
    final more = ref.read(adsPolicyProvider).messagesPerReward;
    // Unlike sending, a missing ad earns nothing here: nothing is blocked.
    if (outcome == RewardOutcome.earned) {
      await ref.read(messageQuotaProvider.notifier).addReward();
    }
    if (!mounted) return;
    setState(() => _loading = false);
    final l10n = context.l10n;
    final text = switch (outcome) {
      RewardOutcome.earned => l10n.rewardAdded(more),
      RewardOutcome.skipped => l10n.rewardEarnSkipped,
      RewardOutcome.unavailable => l10n.rewardUnavailable,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final policy = ref.watch(adsPolicyProvider);
    final more = policy.messagesPerReward;
    final theme = Theme.of(context);
    // A real button, so it does not read as one more line of the count.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            key: const Key('earn-messages'),
            onPressed: _loading ? null : _watch,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(l10n.rewardEarnMore),
          ),
          const SizedBox(height: 6),
          Text(
            policy.carryOver > 0
                ? l10n.rewardEarnMoreCarry(more, policy.carryOver)
                : l10n.rewardEarnMoreSubtitle(more),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
