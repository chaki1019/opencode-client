import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import 'composer_providers.dart';

enum SessionAction { rename, fork, compact, delete }

/// The overflow menu of the chat screen.
class SessionActionsMenu extends ConsumerWidget {
  const SessionActionsMenu({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<SessionAction>(
      key: const Key('session-menu'),
      onSelected: (action) => switch (action) {
        SessionAction.rename => renameSession(context, ref, session),
        SessionAction.fork => forkSession(context, ref, session),
        SessionAction.compact => compactSession(context, ref, session),
        SessionAction.delete => deleteSession(context, ref, session),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: SessionAction.rename,
          child: ListTile(leading: Icon(Icons.edit), title: Text('名前を変更')),
        ),
        PopupMenuItem(
          value: SessionAction.fork,
          child: ListTile(leading: Icon(Icons.fork_right), title: Text('フォーク')),
        ),
        PopupMenuItem(
          value: SessionAction.compact,
          child: ListTile(leading: Icon(Icons.compress), title: Text('会話を要約')),
        ),
        PopupMenuItem(
          value: SessionAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('削除'),
          ),
        ),
      ],
    );
  }
}

/// Runs [action] and shows [failure] with the server's reason if it throws.
Future<T?> _guard<T>(
  BuildContext context,
  String failure,
  Future<T> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await action();
  } on OpenCodeApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$failure: ${e.detail}')));
    return null;
  }
}

Future<void> renameSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return;
  final router = GoRouter.of(context);
  final title = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: session.title ?? ''),
  );
  if (title == null || title.trim().isEmpty || !context.mounted) return;
  final updated = await _guard(
    context,
    '名前を変更できませんでした',
    () => client.renameSession(session.id, title.trim()),
  );
  // Reopen the chat with the renamed session so the title updates.
  if (updated != null) {
    router.replace(
      '/sessions/${Uri.encodeComponent(updated.id)}',
      extra: updated,
    );
  }
}

/// Forks [session] and opens the copy. With [beforeMessageId], the copy
/// ends just before that message.
Future<void> forkSession(
  BuildContext context,
  WidgetRef ref,
  Session session, {
  String? beforeMessageId,
}) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return;
  final router = GoRouter.of(context);
  final fork = await _guard(
    context,
    'フォークできませんでした',
    () => client.forkSession(session.id, beforeMessageId: beforeMessageId),
  );
  if (fork != null) {
    router.push('/sessions/${Uri.encodeComponent(fork.id)}', extra: fork);
  }
}

Future<void> compactSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final id = ref.read(idsProvider).message();
  final done = await _guard(context, '要約を依頼できませんでした', () async {
    await client.compactSession(session.id, messageId: id);
    return true;
  });
  if (done == true) {
    messenger.showSnackBar(const SnackBar(content: Text('会話の要約を依頼しました')));
  }
}

Future<void> deleteSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return;
  final router = GoRouter.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('セッションを削除しますか？'),
      content: Text('「${session.displayTitle}」を削除します。元に戻せません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final done = await _guard(context, '削除できませんでした', () async {
    await client.deleteSession(session.id);
    return true;
  });
  if (done == true && router.canPop()) router.pop();
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('名前を変更'),
      content: TextField(
        key: const Key('rename-field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'セッション名'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('confirm-rename'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('変更'),
        ),
      ],
    );
  }
}
