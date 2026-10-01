import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

final worktreesProvider = FutureProvider.autoDispose
    .family<List<Worktree>, String>((ref, projectId) async {
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return const [];
      return client.listWorktrees(projectId);
    });

/// The project's checkouts. Opening one shows its sessions, Git state and
/// files; new sessions started there work in that copy.
class WorktreesScreen extends ConsumerWidget {
  const WorktreesScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = worktreesProvider(project.id);
    final worktrees = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('worktree')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-worktree'),
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新しい worktree'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: worktrees.when(
          data: (list) => ListView(
            children: [
              for (final worktree in list)
                ListTile(
                  leading: Icon(
                    worktree.isMain ? Icons.home_outlined : Icons.account_tree,
                  ),
                  title: Text(worktree.isMain ? 'メイン' : worktree.name),
                  subtitle: Text(
                    worktree.directory,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: worktree.directory == project.directory,
                  trailing: worktree.isManaged
                      ? IconButton(
                          tooltip: '削除',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(context, ref, worktree),
                        )
                      : null,
                  onTap: () => _open(context, worktree),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('worktree を読み込めませんでした: $e')],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Worktree worktree) {
    final target = worktree.isMain
        ? project.copyWith(directory: worktree.directory)
        : project.copyWith(
            directory: worktree.directory,
            name: '${project.displayName} · ${worktree.name}',
          );
    GoRouter.of(context)
        .push('/projects/${Uri.encodeComponent(project.id)}', extra: target);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null) return;
    try {
      await client.createWorktree(project.id, name: name);
      ref.invalidate(worktreesProvider(project.id));
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('作成できませんでした: ${e.detail}')),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Worktree worktree,
  ) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      '「${worktree.name}」を削除しますか？',
      'フォルダごと削除します。元に戻せません。',
    )) {
      return;
    }
    var force = false;
    while (true) {
      try {
        await client.removeWorktree(
          project.id,
          worktree.directory,
          force: force,
        );
        ref.invalidate(worktreesProvider(project.id));
        return;
      } on WorktreeDirtyException {
        if (force || !context.mounted) return;
        if (!await _confirm(
          context,
          'コミットしていない変更があります',
          '変更も含めて削除しますか？元に戻せません。',
        )) {
          return;
        }
        force = true;
      } on OpenCodeApiException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('削除できませんでした: ${e.detail}')),
        );
        return;
      }
    }
  }

  static Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('confirm-remove'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        ),
      ) ??
      false;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新しい worktree'),
      content: TextField(
        key: const Key('worktree-name'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '名前（省略するとサーバーが決めます）'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('confirm-worktree'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('作成'),
        ),
      ],
    );
  }
}
