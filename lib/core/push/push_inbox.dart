import '../../l10n/app_localizations.dart';
import '../models/server_config.dart';
import 'push_crypto.dart';
import 'push_message.dart';
import 'push_store.dart';

/// A notification matched to the saved server it came from. [content] is
/// null when it could not be decrypted (it then shows only the headline).
class ResolvedPush {
  const ResolvedPush({required this.server, required this.content});

  final ServerConfig server;
  final PushContent? content;
}

/// Finds the server whose pairing sent [message] and decrypts it. Works
/// without Riverpod so the Android background handler can use it too.
Future<ResolvedPush?> resolvePush(
  PushMessage message, {
  required List<ServerConfig> servers,
  required PushStore store,
}) async {
  for (final server in servers) {
    final pairing = await store.load(server.id);
    if (pairing == null) continue;
    final keys = await PushKeys.derive(pairing.key);
    if (keys.keyId != message.keyId) continue;
    final content = message.enc.isEmpty
        ? null
        : await openPushContent(
            encKey: keys.encKey,
            kind: message.kind.name,
            sessionId: message.sessionId,
            enc: message.enc,
          );
    return ResolvedPush(server: server, content: content);
  }
  return null;
}

/// The title and body a notification shows, in the device language.
({String title, String body}) pushText(
  AppLocalizations l10n,
  PushKind kind,
  PushContent? content,
) {
  final headline = switch (kind) {
    PushKind.completed => l10n.pushHeadlineCompleted,
    PushKind.failed => l10n.pushHeadlineFailed,
    PushKind.permission => l10n.pushHeadlinePermission,
    PushKind.question => l10n.pushHeadlineQuestion,
  };
  final project = content?.project ?? '';
  // A failure's reason is worth more than the session title, so it gets
  // its own line under it.
  final body = kind == PushKind.failed
      ? [content?.title, content?.detail].nonNulls.join('\n')
      : content?.title ?? content?.detail ?? '';
  return (
    title: project.isEmpty ? headline : '$project: $headline',
    body: body,
  );
}
