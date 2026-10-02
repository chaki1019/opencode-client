import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project_tools.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';

/// Terminals running in a project directory, reloaded on `pty.*` events.
class PtyListNotifier extends AsyncNotifier<List<Pty>> {
  PtyListNotifier(this.directory);

  final String directory;

  @override
  Future<List<Pty>> build() async {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const [];
    listenToServerEvents(
      ref,
      onEvent: (event) {
        if (event.type.startsWith('pty.') &&
            (event.directory == null || event.directory == directory)) {
          unawaited(_reload());
        }
      },
      onResync: _reload,
    );
    return client.listPtys(directory: directory);
  }

  Future<void> _reload() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null || !ref.mounted) return;
    try {
      final list = await client.listPtys(directory: directory);
      if (ref.mounted) state = AsyncData(list);
    } catch (_) {
      // Keep the last list; pull to refresh retries.
    }
  }

  /// [title] names the new terminal from its position in the list.
  Future<Pty?> create(String Function(int count) title) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return null;
    final count = (state.value?.length ?? 0) + 1;
    final pty = await client.createPty(
      directory: directory,
      title: title(count),
    );
    await _reload();
    return pty;
  }

  Future<void> delete(Pty pty) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    await client.deletePty(pty.id, directory: directory);
    await _reload();
  }
}

final ptyListProvider = AsyncNotifierProvider.autoDispose
    .family<PtyListNotifier, List<Pty>, String>(PtyListNotifier.new);
