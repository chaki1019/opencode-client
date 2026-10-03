import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/session.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../home/pane_selection.dart';
import 'composer_providers.dart';

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

/// Asks for a new title and renames [session]. Returns the renamed session,
/// or null if cancelled or failed.
Future<Session?> renameSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return null;
  final title = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: session.title ?? ''),
  );
  if (title == null || title.trim().isEmpty || !context.mounted) return null;
  return _guard(
    context,
    context.l10n.renameFailed,
    () => client.renameSession(session.id, title.trim()),
  );
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
  final panes = ref.read(paneSelectionProvider.notifier);
  final fork = await _guard(
    context,
    context.l10n.forkFailed,
    () => client.forkSession(session.id, beforeMessageId: beforeMessageId),
  );
  if (fork != null) openSession(router, panes, fork);
}

Future<void> compactSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final id = ref.read(idsProvider).message();
  final done = await _guard(context, context.l10n.compactFailed, () async {
    await client.compactSession(session.id, messageId: id);
    return true;
  });
  if (done == true) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.compactRequested)));
  }
}

/// Asks for confirmation and deletes [session]. Returns whether it was
/// deleted.
Future<bool> deleteSession(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final client = ref.read(connectionProvider)?.client;
  if (client == null) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.deleteSessionTitle),
      content: Text(
        context.l10n.deleteSessionBody(
          session.displayTitle ?? context.l10n.untitledSession,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final done = await _guard(context, context.l10n.deleteFailed, () async {
    await client.deleteSession(session.id);
    return true;
  });
  return done == true;
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
      title: Text(context.l10n.rename),
      content: TextField(
        key: const Key('rename-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.sessionName),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-rename'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.l10n.renameConfirm),
        ),
      ],
    );
  }
}
