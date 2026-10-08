import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/api/opencode_client.dart';
import '../../core/push/computer_plugin.dart';
import '../../core/push/push_config.dart';
import '../../core/push/push_crypto.dart';
import '../../core/push/push_inbox.dart';
import '../../core/push/push_message.dart';
import '../../core/push/push_messaging.dart';
import '../../core/push/push_store.dart';
import '../../core/push/relay_client.dart';
import '../../l10n/l10n.dart';
import '../attention/attention_providers.dart';
import '../connection/connection_providers.dart';
import '../home/pane_selection.dart';

/// Overridden in tests; real builds read `--dart-define`s.
final pushConfigProvider = Provider<PushConfig>(
  (ref) => const PushConfig.fromEnvironment(),
);

/// Null when this build has push turned off.
final pushMessagingProvider = Provider<PushMessaging?>(
  (ref) => pushMessagingFor(ref.watch(pushConfigProvider)),
);

final relayClientProvider = Provider<RelayClient>(
  (ref) => RelayClient(ref.watch(pushConfigProvider).relayUrl),
);

final pushStoreProvider = Provider<PushStore>((ref) => PushStore());

/// Lets push code outside the widget tree show a snack bar.
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>(
      (ref) => GlobalKey<ScaffoldMessengerState>(),
    );

enum PushSetupError { notConfigured, permissionDenied, noToken }

class PushSetupException implements Exception {
  const PushSetupException(this.error);

  final PushSetupError error;
}

/// One saved server's notification pairing. A key is made up the first
/// time the screen opens; it gives way to the computer's own key as soon as
/// [computerPluginProvider] finds one.
class PushPairingNotifier extends AsyncNotifier<PushPairing> {
  PushPairingNotifier(this.serverId);

  final String serverId;

  PushStore get _store => ref.read(pushStoreProvider);

  @override
  Future<PushPairing> build() async {
    final saved = await _store.load(serverId);
    if (saved != null) return saved;
    final pairing = PushPairing(key: PushPairing.newKey());
    await _store.save(serverId, pairing);
    return pairing;
  }

  /// Asks for permission, then registers this device with the relay.
  /// Throws [PushSetupException] or [RelayException].
  Future<void> enable() async {
    final messaging = ref.read(pushMessagingProvider);
    if (messaging == null) {
      throw const PushSetupException(PushSetupError.notConfigured);
    }
    if (!await messaging.requestPermission()) {
      throw const PushSetupException(PushSetupError.permissionDenied);
    }
    final token = await messaging.token();
    if (token == null) throw const PushSetupException(PushSetupError.noToken);
    final pairing = await future;
    final keys = await PushKeys.derive(pairing.key);
    await messaging.shareKeys(keys);
    await ref
        .read(relayClientProvider)
        .register(
          key: keys.auth,
          token: token,
          platform: ref.read(pushConfigProvider).platform,
        );
    final updated = pairing.copyWith(enabled: true, token: token);
    await _store.save(serverId, updated);
    state = AsyncData(updated);
  }

  /// Stops notifications for this server. The relay is told on a best
  /// effort basis; the local switch turns off either way.
  Future<void> disable() async {
    final pairing = await future;
    await _unregister(
      relay: ref.read(relayClientProvider),
      messaging: ref.read(pushMessagingProvider),
      pairing: pairing,
    );
    final updated = PushPairing(key: pairing.key);
    await _store.save(serverId, updated);
    state = AsyncData(updated);
  }

  /// Switches this server's pairing to [key], the one the plugin on the
  /// computer uses, so this device receives what it sends.
  /// Re-registers with the relay when notifications were on.
  Future<void> adoptKey(String key) async {
    final pairing = await future;
    if (pairing.key == key) return;
    await _unregister(
      relay: ref.read(relayClientProvider),
      messaging: ref.read(pushMessagingProvider),
      pairing: pairing,
    );
    final adopted = PushPairing(key: key);
    await _store.save(serverId, adopted);
    state = AsyncData(adopted);
    if (pairing.enabled) await enable();
  }

  /// Sends [title] through the relay, encrypted like the plugin does.
  Future<void> sendTest(String title) async {
    final keys = await PushKeys.derive((await future).key);
    final enc = await sealPushContent(
      encKey: keys.encKey,
      kind: PushKind.completed.name,
      sessionId: '',
      content: PushContent(project: '', title: title),
    );
    await ref.read(relayClientProvider).sendTest(auth: keys.auth, enc: enc);
  }
}

final pushPairingProvider = AsyncNotifierProvider.autoDispose
    .family<PushPairingNotifier, PushPairing, String>(PushPairingNotifier.new);

/// Whether OpenCode on the connected computer runs the push plugin with
/// this server's pairing. Null when the server can't tell (an older
/// version, or the request failed).
///
/// The computer's key is the one that counts: when the plugin uses another
/// key with this relay (one it created, or one another device set up), this
/// device switches to it, so every device connected to that computer gets
/// its notifications.
/// The newest push plugin version on npm, or null when the registry can't
/// be reached. Read straight from the public registry; the version number
/// is all the app asks for.
final latestPushPluginVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final response =
        await Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ).get<Map<String, dynamic>>(
          'https://registry.npmjs.org/$pushPluginPackage/latest',
        );
    final version = response.data?['version'];
    return version is String ? version : null;
  } on Object {
    return null;
  }
});

final computerPluginProvider = FutureProvider.autoDispose
    .family<ComputerPluginCheck?, String>((ref, serverId) async {
      final client = ref.watch(serverClientProvider(serverId));
      if (client == null) return null;
      final pairing = await ref.watch(pushPairingProvider(serverId).future);
      final relayUrl = ref.watch(pushConfigProvider).relayUrl;
      final ComputerPluginCheck check;
      try {
        final (plugins, raw, latest) = await (
          client.listPlugins(),
          client.readConfig(),
          ref.watch(latestPushPluginVersionProvider.future),
        ).wait;
        var config = raw;
        final fromFolder =
            config.entries.isEmpty && plugins.any((p) => p.isPush);
        if (config.needsSettings || fromFolder) {
          final settings = await _readPushSettings(
            client,
            pushSettingsDirectories(config, plugins),
          );
          config = config.withSettings(settings, loadedFromFolder: fromFolder);
        }
        check = checkComputerPlugin(
          plugins: plugins,
          config: config,
          relayUrl: relayUrl,
          key: pairing.key,
          latestVersion: latest,
        );
      } on Object {
        return null;
      }
      final shared = check.sharedKey;
      if (shared == null) return check;
      try {
        // Rebuilds this check with the new key once it is saved.
        await ref.read(pushPairingProvider(serverId).notifier).adoptKey(shared);
      } on Object {
        // Saved, but the relay or the permission prompt failed; the switch
        // shows it off and turning it on again registers the new key.
      }
      return check;
    });

/// Has OpenCode on the computer of [serverId] install the newest version of
/// the push plugin ([target] as `GET /api/plugin` names it), then checks
/// the plugin again. The new version reads or creates its pairing key as it
/// starts, so the check waits [settle] for that first.
Future<void> updatePushPlugin(
  WidgetRef ref,
  String serverId,
  String target, {
  Duration settle = const Duration(seconds: 2),
}) async {
  final client = ref.read(serverClientProvider(serverId));
  if (client == null) return;
  await client.updatePlugins([target]);
  await Future<void>.delayed(settle);
  ref.invalidate(computerPluginProvider(serverId));
}

/// The first settings file found in [directories], read through the
/// OpenCode server.
Future<PushSettingsFile?> _readPushSettings(
  OpenCodeClient client,
  List<String> directories,
) async {
  for (final directory in directories) {
    try {
      final file = await client.readFile(
        directory: directory,
        path: pushSettingsFileName,
      );
      final settings = PushSettingsFile.tryParse(file.text);
      if (settings?.key != null) return settings;
    } on Object {
      // Not there, or the server can't read outside a project.
    }
  }
  return null;
}

Future<void> _unregister({
  required RelayClient relay,
  required PushMessaging? messaging,
  required PushPairing pairing,
}) async {
  final token = pairing.token;
  if (!pairing.enabled || token == null) return;
  final keys = await PushKeys.derive(pairing.key);
  try {
    await messaging?.unshareKeys(keys.keyId);
    await relay.unregister(key: keys.auth, token: token);
  } on Object {
    // Offline or relay gone; the relay drops the token when FCM reports
    // it unregistered.
  }
}

/// Unregisters a server that is being removed from the saved list.
Future<void> forgetPush(WidgetRef ref, String serverId) async {
  final store = ref.read(pushStoreProvider);
  final pairing = await store.load(serverId);
  if (pairing != null) {
    await _unregister(
      relay: ref.read(relayClientProvider),
      messaging: ref.read(pushMessagingProvider),
      pairing: pairing,
    );
  }
  await store.delete(serverId);
}

/// Wires platform push into the app: keeps relay registrations current when
/// the FCM token rotates, opens the session a tapped notification is about,
/// and shows notifications that arrive while the app is in front.
final pushCoordinatorProvider = Provider<void>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  if (messaging == null) return;

  final subscriptions = [
    messaging.tokenRefresh.listen((token) => _reregister(ref, token)),
    messaging.taps.listen((message) => openPushMessage(ref, message)),
    messaging.foreground.listen((message) => _showInApp(ref, message)),
  ];
  // The badge is the "needs you" count. Until a connected server has
  // reported, the badge from while the app was away stays as it is.
  ref.listen(attentionKnownProvider, (_, known) => _setBadge(ref, messaging));
  ref.listen(
    attentionProvider.select((items) => items.length),
    (_, _) => _setBadge(ref, messaging),
    fireImmediately: true,
  );
  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });
  unawaited(
    messaging.initialTap().then((message) {
      if (message != null) return openPushMessage(ref, message);
    }, onError: (Object _) {}),
  );
});

void _setBadge(Ref ref, PushMessaging messaging) {
  if (!ref.read(attentionKnownProvider)) return;
  final count = ref.read(attentionProvider).length;
  unawaited(messaging.setBadge(count).catchError((Object _) {}));
}

Future<void> _reregister(Ref ref, String token) async {
  final store = ref.read(pushStoreProvider);
  final config = ref.read(pushConfigProvider);
  for (final server in await ref.read(savedServersProvider.future)) {
    final pairing = await store.load(server.id);
    if (pairing == null || !pairing.enabled || pairing.token == token) {
      continue;
    }
    try {
      final keys = await PushKeys.derive(pairing.key);
      await ref
          .read(relayClientProvider)
          .register(key: keys.auth, token: token, platform: config.platform);
      await store.save(server.id, pairing.copyWith(token: token));
    } on Object {
      // Retried on the next refresh or when the user toggles the switch.
    }
  }
}

Future<ResolvedPush?> _resolve(Ref ref, PushMessage message) async =>
    resolvePush(
      message,
      servers: await ref.read(savedServersProvider.future),
      store: ref.read(pushStoreProvider),
    );

/// Connects to the server the notification came from (if needed) and opens
/// its session.
Future<void> openPushMessage(Ref ref, PushMessage message) async {
  if (!message.hasSession) return;
  final server = (await _resolve(ref, message))?.server;
  if (server == null) return;
  try {
    final connection = ref.read(connectionProvider.notifier);
    if (ref.read(connectionProvider)?.server.id != server.id) {
      await connection.connectSaved(server);
    }
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final session = await client.getSession(message.sessionId);
    final router = ref.read(routerProvider);
    router.go('/projects');
    openSession(router, ref.read(paneSelectionProvider.notifier), session);
  } on Object catch (e) {
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    final context = messenger?.context;
    if (messenger == null || context == null || !context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.pushOpenFailed('$e'))),
    );
  }
}

Future<void> _showInApp(Ref ref, PushMessage message) async {
  final resolved = await _resolve(ref, message);
  if (resolved == null) return;
  // The user is looking at that session already.
  if (ref.read(connectionProvider)?.server.id == resolved.server.id &&
      ref.read(openChatsProvider).contains(message.sessionId)) {
    return;
  }
  final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
  final context = messenger?.context;
  if (messenger == null || context == null || !context.mounted) return;
  final text = pushText(context.l10n, message.kind, resolved.content);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        [text.title, text.body].where((s) => s.isNotEmpty).join('\n'),
      ),
      action: message.hasSession
          ? SnackBarAction(
              label: context.l10n.pushOpen,
              onPressed: () => openPushMessage(ref, message),
            )
          : null,
    ),
  );
}
