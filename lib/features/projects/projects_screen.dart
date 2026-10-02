import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/project.dart';
import '../connection/connection_providers.dart';
import '../live/live_widgets.dart';
import 'project_providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final projects = ref.watch(projectsProvider);
    final health = connection?.health;

    return Scaffold(
      appBar: AppBar(
        title: Text(connection?.server.displayName ?? 'プロジェクト'),
        actions: [
          IconButton(
            tooltip: '切断',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          ),
        ],
        bottom: health == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final project in _sorted(bootstrap.projects))
                _ProjectTile(
                  project: project,
                  isCurrent: project.id == bootstrap.current?.id,
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('プロジェクトを読み込めませんでした: $e')],
          ),
        ),
      ),
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
                '現在',
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
