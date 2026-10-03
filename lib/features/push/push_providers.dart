import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/push/push_config.dart';
import '../../core/push/push_crypto.dart';
import '../../core/push/push_inbox.dart';
import '../../core/push/push_message.dart';
import '../../core/push/push_messaging.dart';
import '../../core/push/push_store.dart';
import '../../core/push/relay_client.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';

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

/// One saved server's notification pairing. The key is created the first
/// time the screen opens so the plugin snippet stays the same afterwards.
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
    unawaited(router.push('/sessions/${session.id}', extra: session));
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
