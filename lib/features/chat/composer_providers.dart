import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../../core/ids.dart';
import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import 'chat_providers.dart';

final idsProvider = Provider<OpenCodeIds>((ref) => OpenCodeIds());

enum PendingStatus { sending, uncertain }

/// A prompt the user sent that is not in the transcript yet.
class PendingPrompt {
  const PendingPrompt({
    required this.id,
    required this.text,
    this.status = PendingStatus.sending,
  });

  final String id;
  final String text;
  final PendingStatus status;

  PendingPrompt withStatus(PendingStatus status) =>
      PendingPrompt(id: id, text: text, status: status);
}

/// Prompts in flight for one session. A prompt leaves this list when its
/// ID shows up in the transcript (the server promoted it), or when the user
/// dismisses a failed one. Nothing is ever resent automatically: an
/// uncertain send is reconciled by refetching the transcript.
class PendingPromptsNotifier extends Notifier<List<PendingPrompt>> {
  PendingPromptsNotifier(this.sessionId);

  final String sessionId;

  @override
  List<PendingPrompt> build() {
    ref.listen(timelineProvider(sessionId), (_, next) {
      final ids = {for (final e in next.value?.items ?? const []) e.id};
      if (state.any((p) => ids.contains(p.id))) {
        state = state.where((p) => !ids.contains(p.id)).toList();
      }
    });
    return const [];
  }

  /// Sends [text]. Returns false when the server rejected it, so the caller
  /// can put the text back into the input.
  Future<bool> send(String text) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return false;
    final id = ref.read(idsProvider).message();
    state = [...state, PendingPrompt(id: id, text: text)];
    final admission = await client.sendPrompt(
      sessionId: sessionId,
      messageId: id,
      text: text,
    );
    if (!ref.mounted) return true;
    switch (admission) {
      case PromptAdmission.accepted:
        return true;
      case PromptAdmission.rejected:
        state = state.where((p) => p.id != id).toList();
        return false;
      case PromptAdmission.uncertain:
        _mark(id, PendingStatus.uncertain);
        unawaited(ref.read(timelineProvider(sessionId).notifier).resync());
        return true;
    }
  }

  void dismiss(String id) => state = state.where((p) => p.id != id).toList();

  void _mark(String id, PendingStatus status) =>
      state = [for (final p in state) p.id == id ? p.withStatus(status) : p];
}

final pendingPromptsProvider = NotifierProvider.autoDispose
    .family<PendingPromptsNotifier, List<PendingPrompt>, String>(
      PendingPromptsNotifier.new,
    );

/// The agent and model the session runs with, starting from what the
/// session record says and updated when the user picks another.
class SessionSettings {
  const SessionSettings({this.agent, this.model});

  final String? agent;
  final ModelRef? model;
}

class SessionSettingsNotifier extends Notifier<SessionSettings> {
  SessionSettingsNotifier(this.session);

  final Session session;

  @override
  SessionSettings build() =>
      SessionSettings(agent: session.agent, model: session.model);

  Future<void> selectAgent(String agentId) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    await client.selectAgent(session.id, agentId);
    if (ref.mounted) {
      state = SessionSettings(agent: agentId, model: state.model);
    }
  }

  Future<void> selectModel(ModelRef model) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    await client.selectModel(session.id, model);
    if (ref.mounted) {
      state = SessionSettings(agent: state.agent, model: model);
    }
  }
}

final sessionSettingsProvider = NotifierProvider.autoDispose
    .family<SessionSettingsNotifier, SessionSettings, Session>(
      SessionSettingsNotifier.new,
    );

final agentsProvider = FutureProvider.autoDispose
    .family<List<AgentInfo>, String>((ref, directory) async {
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return const [];
      final agents = await client.listAgents(directory: directory);
      return agents.where((a) => a.isSelectable).toList();
    });

final modelsProvider = FutureProvider.autoDispose
    .family<List<ModelOption>, String>((ref, directory) {
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return const [];
      return client.listModels(directory: directory);
    });
