import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../chat/context_sheet.dart' show UsageRing;
import 'ads_providers.dart';
import 'ads_settings_section.dart';

/// Today's messages left, as a ring with the number inside, next to the
/// send button. Tapping it shows the count and a rewarded ad for more.
/// Nothing while sending is not limited.
class MessageQuotaRing extends ConsumerWidget {
  const MessageQuotaRing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rewardedActiveProvider)) return const SizedBox.shrink();
    ref.watch(messageQuotaProvider);
    final quota = ref.read(messageQuotaProvider.notifier).today;
    final scheme = Theme.of(context).colorScheme;
    final color = quota.remaining == 0 ? scheme.error : scheme.primary;
    final fraction = quota.free == 0
        ? 1.0
        : (quota.sent / quota.free).clamp(0.0, 1.0);
    final label = context.l10n.messagesLeft(quota.remaining);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const Key('message-quota'),
          radius: 22,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [MessageCountTile(), EarnMessagesTile()],
              ),
            ),
          ),
          child: SizedBox(
            width: 40,
            height: 48,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  UsageRing(
                    fraction: fraction,
                    size: 28,
                    strokeWidth: 3,
                    color: color,
                    trackColor: scheme.outlineVariant,
                  ),
                  Text(
                    '${quota.remaining}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
