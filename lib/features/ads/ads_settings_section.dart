import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'ads_providers.dart';
import 'remove_ads.dart';

/// Whether the user must be offered their ad consent again.
final _privacyOptionsProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!ref.watch(adsActiveProvider)) return false;
  return ref.watch(adsServiceProvider).privacyOptionsRequired();
});

/// The settings page's ad rows: today's free messages, the "remove ads"
/// purchase and the consent form. Empty where the app shows no ads.
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
    ref.watch(messageQuotaProvider);
    final quota = ref.read(messageQuotaProvider.notifier).today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(l10n.settingsAds),
        if (removed)
          ListTile(
            key: const Key('ads-removed'),
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.removeAdsDone),
          )
        else ...[
          ListTile(
            key: const Key('ads-free-left'),
            title: Text(l10n.adsFreeLeft),
            trailing: Text(l10n.adsFreeLeftValue(quota.remaining)),
          ),
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
      ],
    );
  }
}
