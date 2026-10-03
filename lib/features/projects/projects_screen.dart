import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/project.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_widgets.dart';
import 'project_providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  /// Leading edge shared by the title, the section header and the project
  /// list card.
  static const double _edge = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final projects = ref.watch(projectsProvider);
    final health = connection?.health;

    return Scaffold(
      appBar: AppBar(
        // Root screen with no back button: line the title up with the
        // project list's leading edge instead of the theme's tight spacing.
        titleSpacing: _edge,
        title: Text(connection?.server.displayName ?? context.l10n.projects),
        actions: [
          IconButton(
            tooltip: context.l10n.disconnect,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          ),
        ],
        bottom: health == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_edge, 0, 16, 6),
                  child: Row(
                    children: [
                      LiveDot(
                        size: 6,
                        color: AppColors.of(context).success,
                        pulse: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OpenCode ${health.version}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: projects.when(
          data: (bootstrap) => ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _SectionHeader(
                title: context.l10n.projects,
                onAdd: () => _addProject(context, ref),
              ),
              if (bootstrap.projects.isNotEmpty)
                Card(
                  key: const Key('project-list'),
                  margin: const EdgeInsets.symmetric(horizontal: _edge),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, project) in _sorted(
                        bootstrap.projects,
                      ).indexed) ...[
                        if (i > 0) const Divider(),
                        _ProjectTile(
                          project: project,
                          isCurrent: project.id == bootstrap.current?.id,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(context.l10n.projectsLoadFailed(e))],
          ),
        ),
      ),
    );
  }

  Future<void> _addProject(BuildContext context, WidgetRef ref) async {
    final project = await showDialog<Project>(
      context: context,
      builder: (_) => const _AddProjectDialog(),
    );
    if (project == null || !context.mounted) return;
    ref.invalidate(projectsProvider);
    context.push(
      '/projects/${Uri.encodeComponent(project.id)}',
      extra: project,
    );
  }

  List<Project> _sorted(List<Project> projects) {
    double updated(Project p) => p.time?.updated ?? p.time?.created ?? 0;
    return [...projects]..sort((a, b) => updated(b).compareTo(updated(a)));
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.isCurrent});

  final Project project;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = project.displayName;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          name.isEmpty ? '/' : name.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: scheme.primary,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        project.directory,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: AppFonts.mono,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                context.l10n.currentProject,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            )
          : null,
      onTap: () => context.push(
        '/projects/${Uri.encodeComponent(project.id)}',
        extra: project,
      ),
    );
  }
}

/// "Projects" label on the left with the add button on its right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ProjectsScreen._edge, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('add-project'),
            tooltip: context.l10n.addProject,
            icon: const Icon(Icons.add),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Asks for a folder on the server and opens it as a project. Pops with
/// the resolved [Project], or null when cancelled.
class _AddProjectDialog extends ConsumerStatefulWidget {
  const _AddProjectDialog();

  @override
  ConsumerState<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<_AddProjectDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final path = _normalize(_controller.text);
    if (!_isAbsolute(path)) {
      setState(() => _error = l10n.projectFolderMustBeAbsolute);
      return;
    }
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final project = await client.openProject(path);
      if (mounted) Navigator.pop(context, project);
    } on OpenCodeApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.projectOpenFailed(e.detail);
        });
      }
    }
  }

  static String _normalize(String input) {
    final path = input.trim();
    if (path.length > 1 && (path.endsWith('/') || path.endsWith(r'\'))) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  static bool _isAbsolute(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.addProject),
      content: TextField(
        key: const Key('project-folder'),
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontFamily: AppFonts.mono),
        decoration: InputDecoration(
          labelText: context.l10n.projectFolderLabel,
          hintText: context.l10n.projectFolderHint,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-add-project'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.openProject),
        ),
      ],
    );
  }
}
