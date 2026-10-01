import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/opencode_client.dart';
import '../../core/ids.dart';
import '../../core/models/attachment.dart';
import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import 'chat_providers.dart';

final idsProvider = Provider<OpenCodeIds>((ref) => OpenCodeIds());

/// Picks images from the photo library or, with [camera], takes one.
typedef PickImages = Future<List<PromptFile>> Function({bool camera});

final pickImagesProvider = Provider<PickImages>((ref) => pickImages);

Future<List<PromptFile>> pickImages({bool camera = false}) async {
  final picker = ImagePicker();
  // Downscale so photos stay well under the attachment limits.
  const maxSide = 2048.0;
  final picked = camera
      ? [
          ?await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: maxSide,
            maxHeight: maxSide,
            imageQuality: 85,
          ),
        ]
      : await picker.pickMultiImage(
          maxWidth: maxSide,
          maxHeight: maxSide,
          imageQuality: 85,
        );
  return [
    for (final file in picked)
      PromptFile(
        name: file.name,
        mime: file.mimeType ?? PromptFile.mimeForName(file.name),
        bytes: await file.readAsBytes(),
      ),
  ];
}

enum PendingStatus { sending, uncertain }

/// A prompt the user sent that is not in the transcript yet.
class PendingPrompt {
  const PendingPrompt({
    required this.id,
    required this.text,
    this.files = const [],
    this.status = PendingStatus.sending,
  });

  final String id;
  final String text;
  final List<PromptFile> files;
  final PendingStatus status;

  PendingPrompt withStatus(PendingStatus status) =>
      PendingPrompt(id: id, text: text, files: files, status: status);
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
  Future<bool> send(String text, {List<PromptFile> files = const []}) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return false;
    final id = ref.read(idsProvider).message();
    state = [...state, PendingPrompt(id: id, text: text, files: files)];
    final admission = await client.sendPrompt(
      sessionId: sessionId,
      messageId: id,
      text: text,
      files: files,
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
