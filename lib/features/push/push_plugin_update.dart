import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'push_providers.dart';

/// Offers OpenCode's own plugin update when a newer push plugin is out.
/// OpenCode installs an npm plugin once and keeps it until asked to update,
/// so without this the computer stays on the old version. Shows nothing
/// while the plugin is current.
class PushPluginUpdate extends ConsumerStatefulWidget {
  const PushPluginUpdate({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<PushPluginUpdate> createState() => _PushPluginUpdateState();
}

class _PushPluginUpdateState extends ConsumerState<PushPluginUpdate> {
  bool _busy = false;

  Future<void> _update(String target) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await updatePushPlugin(ref, widget.serverId, target);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pushPluginUpdated)));
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.pushPluginUpdateFailed('$e'))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(computerPluginProvider(widget.serverId)).value;
    final target = check?.updateTarget;
    if (target == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final latest = check?.latestVersion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest == null
                ? l10n.pushPluginOutdated
                : l10n.pushPluginOutdatedTo(latest),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('push-plugin-update'),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            label: Text(l10n.pushPluginUpdate),
            onPressed: _busy ? null : () => _update(target),
          ),
        ],
      ),
    );
  }
}
