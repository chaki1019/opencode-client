import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/models/server_config.dart';
import '../../core/push/computer_plugin.dart';
import '../../core/push/push_store.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import 'push_providers.dart';

/// The `opencode.json` entry that loads the plugin with this pairing.
String pluginConfigSnippet({required String relayUrl, required String key}) =>
    '''
"plugins": [
  {
    "package": "opencode-mobile-push",
    "options": {
      "relay": "$relayUrl",
      "key": "$key"
    }
  }
]''';

/// Turns notifications on for the connected server and shows what to add
/// to OpenCode on the computer.
class PushSettingsScreen extends ConsumerWidget {
  const PushSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(connectionProvider)?.server;
    final config = ref.watch(pushConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pushTitle)),
      body: server == null
          ? const SizedBox.shrink()
          : !config.isConfigured
          ? _Message(context.l10n.pushNotConfigured)
          : _PairingView(server: server, relayUrl: config.relayUrl),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, key: const Key('push-message')),
  );
}

class _PairingView extends ConsumerStatefulWidget {
  const _PairingView({required this.server, required this.relayUrl});

  final ServerConfig server;
  final String relayUrl;

  @override
  ConsumerState<_PairingView> createState() => _PairingViewState();
}

class _PairingViewState extends ConsumerState<_PairingView> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
      if (done != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
    } on PushSetupException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.error) {
            PushSetupError.notConfigured => l10n.pushNotConfigured,
            PushSetupError.permissionDenied => l10n.pushPermissionDenied,
            PushSetupError.noToken => l10n.pushNoToken,
          }),
        ),
      );
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pushFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = pushPairingProvider(widget.server.id);
    final pairing = ref.watch(provider);
    return pairing.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(context.l10n.pushFailed('$e')),
      data: (pairing) => ListView(
        padding: EdgeInsets.fromLTRB(
          readableSide(context),
          0,
          readableSide(context),
          24,
        ),
        children: [
          SwitchListTile(
            key: const Key('push-switch'),
            title: Text(context.l10n.pushReceive),
            subtitle: Text(widget.server.displayName),
            value: pairing.enabled,
            onChanged: _busy
                ? null
                : (on) => _run(
                    on
                        ? ref.read(provider.notifier).enable
                        : ref.read(provider.notifier).disable,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              context.l10n.pushWhat,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (pairing.enabled) ...[
            _ComputerStatus(
              serverId: widget.server.id,
              onAdopt: _busy
                  ? null
                  : (key) => _run(
                      () => ref.read(provider.notifier).adoptKey(key),
                      done: context.l10n.pushComputerAdopted,
                    ),
            ),
            _Setup(relayUrl: widget.relayUrl, pairing: pairing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                key: const Key('push-test'),
                icon: const Icon(Icons.send_outlined),
                label: Text(context.l10n.pushSendTest),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(provider.notifier)
                            .sendTest(context.l10n.pushTestTitle),
                        done: context.l10n.pushTestSent,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComputerStatus extends ConsumerWidget {
  const _ComputerStatus({required this.serverId, this.onAdopt});

  final String serverId;

  /// Switches this device to the key `opencode.json` already uses.
  final void Function(String key)? onAdopt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final provider = computerPluginProvider(serverId);
    final check = ref.watch(provider);
    final (icon, color, text) = switch (check) {
      AsyncData(value: final check?) => switch (check.status) {
        ComputerPluginStatus.active => (
          Icons.check_circle_outline,
          colors.primary,
          l10n.pushComputerActive,
        ),
        ComputerPluginStatus.failed => (
          Icons.error_outline,
          colors.error,
          l10n.pushComputerFailed(check.error ?? ''),
        ),
        ComputerPluginStatus.otherKey => (
          Icons.key_off_outlined,
          colors.error,
          l10n.pushComputerOtherKey,
        ),
        ComputerPluginStatus.notLoaded => (
          Icons.restart_alt,
          colors.tertiary,
          l10n.pushComputerNotLoaded,
        ),
        ComputerPluginStatus.missing => (
          Icons.radio_button_unchecked,
          colors.onSurfaceVariant,
          l10n.pushComputerMissing,
        ),
      },
      AsyncLoading() => (null, null, null),
      _ => (
        Icons.help_outline,
        colors.onSurfaceVariant,
        l10n.pushComputerUnknown,
      ),
    };
    final sharedKey = switch (check) {
      AsyncData(value: ComputerPluginCheck(:final sharedKey?)) => sharedKey,
      _ => null,
    };
    final tile = ListTile(
      key: const Key('push-computer'),
      leading: icon == null
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      title: Text(l10n.pushComputerTitle),
      subtitle: text == null ? null : Text(text),
      trailing: IconButton(
        key: const Key('push-computer-refresh'),
        tooltip: l10n.pushComputerRefresh,
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(provider),
      ),
    );
    if (sharedKey == null) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.pushComputerAdoptHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FilledButton.tonalIcon(
            key: const Key('push-computer-adopt'),
            icon: const Icon(Icons.key_outlined),
            label: Text(l10n.pushComputerAdopt),
            onPressed: onAdopt == null ? null : () => onAdopt!(sharedKey),
          ),
        ),
      ],
    );
  }
}

class _Setup extends StatelessWidget {
  const _Setup({required this.relayUrl, required this.pairing});

  final String relayUrl;
  final PushPairing pairing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = pluginConfigSnippet(relayUrl: relayUrl, key: pairing.key);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.pushSetupTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(context.l10n.pushSetupSteps, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
                  child: SelectableText(
                    snippet,
                    key: const Key('push-snippet'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.mono,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('push-copy'),
                    tooltip: context.l10n.copy,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final copied = context.l10n.copied;
                      await Clipboard.setData(ClipboardData(text: snippet));
                      messenger.showSnackBar(SnackBar(content: Text(copied)));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
