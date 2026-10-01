import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/project.dart';
import '../connection/connection_providers.dart';
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
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'OpenCode ${health.version}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: projects.when(
          data: (bootstrap) => ListView(
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
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(project.displayName),
      subtitle: Text(project.directory),
      trailing: isCurrent ? const Chip(label: Text('現在')) : null,
      onTap: () => context.push(
        '/projects/${Uri.encodeComponent(project.id)}',
        extra: project,
      ),
    );
  }
}
