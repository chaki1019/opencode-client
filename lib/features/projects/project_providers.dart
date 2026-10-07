import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../core/storage/project_directories_store.dart';
import '../connection/connection_providers.dart';

final projectsProvider = FutureProvider.autoDispose<ProjectBootstrap>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection == null) {
    return const ProjectBootstrap(projects: []);
  }
  return connection.client.loadProjects();
});

final hiddenProjectsStoreProvider = Provider<ProjectDirectoriesStore>(
  (ref) => ProjectDirectoriesStore.hidden(),
);

final pinnedProjectsStoreProvider = Provider<ProjectDirectoriesStore>(
  (ref) => ProjectDirectoriesStore.pinned(),
);

/// Project directories marked on the list (hidden or pinned), by server URL.
class ProjectDirectoriesNotifier
    extends AsyncNotifier<Map<String, Set<String>>> {
  ProjectDirectoriesNotifier(this._storeProvider);

  final Provider<ProjectDirectoriesStore> _storeProvider;

  ProjectDirectoriesStore get _store => ref.read(_storeProvider);

  @override
  Future<Map<String, Set<String>>> build() => _store.load();

  /// Marks [project] on the list of the server at [serverUrl].
  Future<void> add(String serverUrl, Project project) =>
      _change(serverUrl, (marked) => marked.add(project.directory));

  /// Clears the mark on [project], as when a hidden one is opened again.
  Future<void> remove(String serverUrl, Project project) =>
      _change(serverUrl, (marked) => marked.remove(project.directory));

  Future<void> _change(
    String serverUrl,
    bool Function(Set<String> marked) change,
  ) async {
    // Updates the list in the same frame when it is loaded, so a swiped
    // row leaves the tree right away.
    final current = state.value ?? await future;
    final marked = {...?current[serverUrl]};
    if (!change(marked)) return;
    final updated = {...current, serverUrl: marked};
    state = AsyncData(updated);
    await _store.save(updated);
  }
}

/// Project directories taken off the list, by server URL.
final hiddenProjectsProvider =
    AsyncNotifierProvider<ProjectDirectoriesNotifier, Map<String, Set<String>>>(
      () => ProjectDirectoriesNotifier(hiddenProjectsStoreProvider),
    );

/// Project directories pinned to the top of the list, by server URL.
final pinnedProjectsProvider =
    AsyncNotifierProvider<ProjectDirectoriesNotifier, Map<String, Set<String>>>(
      () => ProjectDirectoriesNotifier(pinnedProjectsStoreProvider),
    );

/// URL of the server on screen, which marked projects are kept under.
final serverUrlProvider = Provider.autoDispose<String?>(
  (ref) => ref.watch(connectionProvider.select((c) => c?.server.baseUrl)),
);

/// Directories hidden on the server on screen.
final hiddenOnServerProvider = Provider.autoDispose<Set<String>>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null) return const {};
  return ref.watch(hiddenProjectsProvider).value?[url] ?? const {};
});

/// Directories pinned on the server on screen.
final pinnedOnServerProvider = Provider.autoDispose<Set<String>>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null) return const {};
  return ref.watch(pinnedProjectsProvider).value?[url] ?? const {};
});

/// Whether the project list shows hidden projects too, with a switch on
/// each row to hide or show it.
class ShowAllProjectsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showAllProjectsProvider =
    NotifierProvider.autoDispose<ShowAllProjectsNotifier, bool>(
      ShowAllProjectsNotifier.new,
    );

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
