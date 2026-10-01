import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

/// The branch and changed files of a project directory.
class GitSnapshot {
  const GitSnapshot({required this.branch, required this.files});

  final VcsBranch branch;
  final List<FileChange> files;
}

/// Loads the branch and the changed files with their patches for one
/// directory and [DiffMode]. Working-tree mode also lists files the status
/// reports without a patch (for example untracked ones).
final gitProvider = FutureProvider.autoDispose
    .family<GitSnapshot, (String, DiffMode)>((ref, key) async {
      final (directory, mode) = key;
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) {
        return const GitSnapshot(branch: VcsBranch(), files: []);
      }
      final (branch, diff, status) = await (
        client.vcsBranch(directory: directory),
        client.vcsDiff(directory: directory, mode: mode),
        mode == DiffMode.working
            ? client.vcsStatus(directory: directory)
            : Future.value(const <FileChange>[]),
      ).wait;
      final patched = {for (final f in diff) f.file};
      return GitSnapshot(
        branch: branch,
        files: [...diff, ...status.where((f) => !patched.contains(f.file))],
      );
    });
