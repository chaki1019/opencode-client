import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../live/live_widgets.dart';
import 'git_providers.dart';

/// The project's branch and changed files. Tapping a file opens its diff.
class GitScreen extends ConsumerStatefulWidget {
  const GitScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends ConsumerState<GitScreen> {
  DiffMode _mode = DiffMode.working;

  @override
  Widget build(BuildContext context) {
    final provider = gitProvider((widget.project.directory, _mode));
    final git = ref.watch(provider);
    final branch = git.value?.branch;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.displayName),
        bottom: const LiveStatusBanner(),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.call_split, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch?.current ?? 'ブランチ不明',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<DiffMode>(
              segments: [
                const ButtonSegment(
                  value: DiffMode.working,
                  label: Text('未コミット'),
                ),
                ButtonSegment(
                  value: DiffMode.branch,
                  label: Text(
                    branch?.defaultBranch == null
                        ? 'ブランチ全体'
                        : '${branch!.defaultBranch}との差分',
                  ),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.single),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(provider.future),
              child: git.when(
                data: (snapshot) => snapshot.files.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [Center(child: Text('変更はありません'))],
                      )
                    : ListView(
                        children: [
                          for (final file in snapshot.files)
                            _FileTile(change: file),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [Text('Git の状態を読み込めませんでした: $e')],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.change});

  final FileChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slash = change.file.lastIndexOf('/');
    final name = change.file.substring(slash + 1);
    final folder = slash < 0 ? null : change.file.substring(0, slash);
    return ListTile(
      leading: Icon(switch (change.status) {
        'added' || 'untracked' => Icons.add_circle_outline,
        'deleted' || 'removed' => Icons.remove_circle_outline,
        'renamed' => Icons.drive_file_rename_outline,
        _ => Icons.edit_outlined,
      }, size: 20),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: folder == null
          ? null
          : Text(folder, overflow: TextOverflow.ellipsis),
      trailing: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '+${change.additions}',
              style: const TextStyle(color: Colors.green),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: '−${change.deletions}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DiffScreen(change: change)),
      ),
    );
  }
}

/// One file's unified diff with added and removed lines colored.
class DiffScreen extends StatelessWidget {
  const DiffScreen({super.key, required this.change});

  final FileChange change;

  @override
  Widget build(BuildContext context) {
    final patch = change.patch;
    return Scaffold(
      appBar: AppBar(
        title: Text(change.file, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: patch == null || patch.trim().isEmpty
          ? const Center(child: Text('差分はありません'))
          : DiffView(patch: patch),
    );
  }
}

class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.patch});

  final String patch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = patch.split('\n');
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.4,
    );
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final (
            Color? background,
            Color? foreground,
          ) = line.startsWith('+') && !line.startsWith('+++')
              ? (Colors.green.withValues(alpha: 0.15), null)
              : line.startsWith('-') && !line.startsWith('---')
              ? (scheme.error.withValues(alpha: 0.15), null)
              : line.startsWith('@@')
              ? (scheme.primary.withValues(alpha: 0.08), scheme.primary)
              : (null, null);
          return Container(
            color: background,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              line.isEmpty ? ' ' : line,
              style: style?.copyWith(color: foreground),
            ),
          );
        },
      ),
    );
  }
}
