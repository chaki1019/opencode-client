import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'ads_providers.dart';
import 'ads_service.dart';

/// A banner along the bottom of a list screen, or nothing for users who
/// removed ads. Kept out of the chat so it never crowds the composer.
class AdBanner extends ConsumerWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adsActiveProvider)) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ref.watch(adsServiceProvider).banner(),
      ),
    );
  }
}

/// Lets a message through, or, once today's free messages are used,
/// offers a rewarded ad first. False means the user declined, so the
/// caller keeps the text. An ad that cannot load never blocks sending,
/// and neither does anything while the server has rewarded ads off.
Future<bool> admitMessage(BuildContext context, WidgetRef ref) async {
  if (!ref.read(rewardedActiveProvider)) return true;
  final quota = ref.read(messageQuotaProvider.notifier);
  if (quota.today.remaining > 0) return true;

  final outcome = await showDialog<RewardOutcome>(
    context: context,
    builder: (context) => const _RewardDialog(),
  );
  switch (outcome) {
    case RewardOutcome.earned || RewardOutcome.unavailable:
      await quota.addReward();
      return true;
    case RewardOutcome.skipped:
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.rewardSkipped)));
      }
      return false;
    case null:
      return false;
  }
}

class _RewardDialog extends ConsumerStatefulWidget {
  const _RewardDialog();

  @override
  ConsumerState<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends ConsumerState<_RewardDialog> {
  bool _loading = false;

  Future<void> _watch() async {
    setState(() => _loading = true);
    final outcome = await ref.read(adsServiceProvider).showRewarded();
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final policy = ref.watch(adsPolicyProvider);
    return AlertDialog(
      title: Text(l10n.rewardTitle),
      content: Text(
        l10n.rewardBody(policy.dailyFreeMessages, policy.messagesPerReward),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('watch-reward'),
          onPressed: _loading ? null : _watch,
          child: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.rewardWatch),
        ),
      ],
    );
  }
}
