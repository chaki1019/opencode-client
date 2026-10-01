import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';

/// A folder's entries, folders first, then by name.
final folderProvider = FutureProvider.autoDispose
    .family<List<FsEntry>, (String, String)>((ref, key) async {
      final (directory, path) = key;
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return const [];
      final entries = await client.listFiles(directory: directory, path: path);
      return entries..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    });

/// Files whose path matches a search query.
final fileSearchProvider = FutureProvider.autoDispose
    .family<List<FsEntry>, (String, String)>((ref, key) async {
      final (directory, query) = key;
      final client = ref.watch(connectionProvider)?.client;
      if (client == null || query.trim().isEmpty) return const [];
      return client.findFiles(directory: directory, query: query.trim());
    });

final fileContentProvider = FutureProvider.autoDispose
    .family<FileContent, (String, String)>((ref, key) async {
      final (directory, path) = key;
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) throw StateError('Not connected');
      return client.readFile(directory: directory, path: path);
    });
