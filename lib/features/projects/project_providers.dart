import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

final projectsProvider = FutureProvider.autoDispose<ProjectBootstrap>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection == null) {
    return const ProjectBootstrap(projects: []);
  }
  return connection.client.loadProjects();
});

/// Where the folder picker starts: the server's working directory.
final serverDirectoryProvider = FutureProvider.autoDispose<String>((ref) {
  final client = ref.watch(connectionProvider)?.client;
  if (client == null) throw StateError('Not connected');
  return client.serverDirectory();
});

/// Subfolders of an absolute server folder, by name.
final subfoldersProvider = FutureProvider.autoDispose
    .family<List<FsEntry>, String>((ref, directory) async {
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return const [];
      final entries = await client.listFiles(directory: directory);
      return [
        for (final e in entries)
          if (e.isDirectory) e,
      ]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    });

/// Folders below an absolute server folder whose path matches a query.
final folderSearchProvider = FutureProvider.autoDispose
    .family<List<FsEntry>, (String, String)>((ref, key) async {
      final (directory, query) = key;
      final client = ref.watch(connectionProvider)?.client;
      if (client == null || query.isEmpty) return const [];
      return client.findFiles(
        directory: directory,
        query: query,
        directories: true,
      );
    });
