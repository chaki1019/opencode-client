import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../core/storage/hidden_projects_store.dart';
import '../connection/connection_providers.dart';

final projectsProvider = FutureProvider.autoDispose<ProjectBootstrap>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection == null) {
    return const ProjectBootstrap(projects: []);
  }
  return connection.client.loadProjects();
});

final hiddenProjectsStoreProvider = Provider<HiddenProjectsStore>(
  (ref) => HiddenProjectsStore(),
);

/// Project directories taken off the list, by server URL.
class HiddenProjectsNotifier extends AsyncNotifier<Map<String, Set<String>>> {
  HiddenProjectsStore get _store => ref.read(hiddenProjectsStoreProvider);

  @override
  Future<Map<String, Set<String>>> build() => _store.load();

  /// Takes [project] off the list of the server at [serverUrl].
  Future<void> hide(String serverUrl, Project project) =>
      _change(serverUrl, (hidden) => hidden.add(project.directory));

  /// Puts [project] back on the list, as when it is opened again.
  Future<void> show(String serverUrl, Project project) =>
      _change(serverUrl, (hidden) => hidden.remove(project.directory));

  Future<void> _change(
    String serverUrl,
    bool Function(Set<String> hidden) change,
  ) async {
    // Updates the list in the same frame when it is loaded, so a swiped
    // row leaves the tree right away.
    final current = state.value ?? await future;
    final hidden = {...?current[serverUrl]};
    if (!change(hidden)) return;
    final updated = {...current, serverUrl: hidden};
    state = AsyncData(updated);
    await _store.save(updated);
  }
}

final hiddenProjectsProvider =
    AsyncNotifierProvider<HiddenProjectsNotifier, Map<String, Set<String>>>(
      HiddenProjectsNotifier.new,
    );

/// URL of the server on screen, which hidden projects are kept under.
final serverUrlProvider = Provider.autoDispose<String?>(
  (ref) => ref.watch(connectionProvider.select((c) => c?.server.baseUrl)),
);

/// Directories hidden on the server on screen.
final hiddenOnServerProvider = Provider.autoDispose<Set<String>>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null) return const {};
  return ref.watch(hiddenProjectsProvider).value?[url] ?? const {};
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
