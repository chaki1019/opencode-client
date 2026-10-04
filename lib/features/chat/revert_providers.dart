import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/server_event.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';

/// The message a session is rewound to, or null when nothing is rewound.
/// That message and everything after it are set aside until the rewind is
/// undone ([undo]) or made permanent ([commit], done before the next send).
class RevertNotifier extends Notifier<String?> {
  RevertNotifier(this.session);

  final Session session;

  @override
  String? build() {
    listenToServerEvents(ref, onEvent: _onEvent, onResync: _refresh);
    // The session passed in may be stale, so check what the server has.
    unawaited(_refresh());
    return session.revert?.messageID;
  }

  Future<void> _refresh() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    try {
      final latest = await client.getSession(session.id);
      if (ref.mounted) state = latest.revert?.messageID;
    } catch (_) {
      // Keep what we have; the next event corrects it.
    }
  }

  void _onEvent(ServerEvent event) {
    if (event.sessionId != session.id) return;
    switch (event.type) {
      case 'session.revert.staged' || 'session.next.revert.staged':
        final revert = event.data['revert'];
        final id = revert is Map ? revert['messageID'] : null;
        if (id is String) state = id;
      case 'session.revert.cleared' ||
          'session.next.revert.cleared' ||
          'session.revert.committed' ||
          'session.next.revert.committed':
        state = null;
    }
  }

  /// Rewinds to just before [messageId], undoing its file changes too.
  Future<void> stage(String messageId) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final boundary = await client.stageRevert(session.id, messageId);
    if (ref.mounted) state = boundary;
  }

  /// Brings the set-aside messages and file changes back.
  Future<void> undo() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    await client.clearRevert(session.id);
    if (ref.mounted) state = null;
  }

  /// Drops the set-aside messages for good. A no-op when nothing is rewound.
  Future<void> commit() async {
    if (state == null) return;
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    await client.commitRevert(session.id);
    if (ref.mounted) state = null;
  }
}

final revertProvider = NotifierProvider.autoDispose
    .family<RevertNotifier, String?, Session>(RevertNotifier.new);

/// Text to put into a session's empty composer, such as a rewound prompt.
/// The composer takes it and resets this to null.
class ComposerDraftNotifier extends Notifier<String?> {
  ComposerDraftNotifier(this.sessionId);

  final String sessionId;

  @override
  String? build() => null;

  void offer(String text) => state = text;

  void take() => state = null;
}

final composerDraftProvider = NotifierProvider.autoDispose
    .family<ComposerDraftNotifier, String?, String>(ComposerDraftNotifier.new);
