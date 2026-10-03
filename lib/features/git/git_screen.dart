import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../l10n/l10n.dart';
import '../projects/project_tools.dart';
import 'change_tree.dart';
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

  /// Last branch seen, so the header and the mode labels don't blank out
  /// while the other mode loads.
  VcsBranch? _branch;

  @override
  Widget build(BuildContext context) {
    final provider = gitProvider((widget.project.directory, _mode));
    final git = ref.watch(provider);
    final branch = _branch = git.value?.branch ?? _branch;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: toolSheetAppBar(
        title: 'Git',
        actions: [
          IconButton(
            tooltip: context.l10n.reload,
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
                    branch?.current ?? context.l10n.unknownBranch,
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
                ButtonSegment(
                  value: DiffMode.working,
                  label: Text(context.l10n.uncommitted),
                ),
                ButtonSegment(
                  value: DiffMode.branch,
                  label: Text(
                    branch?.defaultBranch == null
                        ? context.l10n.wholeBranch
                        : context.l10n.diffAgainst(branch!.defaultBranch!),
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
                        children: [Center(child: Text(context.l10n.noChanges))],
                      )
                    : ChangeTree(
                        changes: snapshot.files,
                        fileTile: (change, name, indent) => _FileTile(
                          change: change,
                          name: name,
                          indent: indent,
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [Text(context.l10n.gitLoadFailed(e))],
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
  const _FileTile({
    required this.change,
    required this.name,
    required this.indent,
  });

  final FileChange change;
  final String name;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      minTileHeight: 40,
      contentPadding: EdgeInsets.only(left: indent, right: 16),
      horizontalTitleGap: 8,
      minLeadingWidth: 0,
      leading: Icon(switch (change.status) {
        'added' || 'untracked' => Icons.add_circle_outline,
        'deleted' || 'removed' => Icons.remove_circle_outline,
        'renamed' => Icons.drive_file_rename_outline,
        _ => Icons.edit_outlined,
      }, size: 20),
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      trailing: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '+${change.additions}',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                color: AppColors.of(context).success,
              ),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: '−${change.deletions}',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                color: theme.colorScheme.error,
              ),
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
          ? Center(child: Text(context.l10n.noDiff))
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
    final colors = AppColors.of(context);
    final lines = patch.split('\n');
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppFonts.mono,
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
              ? (colors.addedBackground, null)
              : line.startsWith('-') && !line.startsWith('---')
              ? (colors.removedBackground, null)
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
