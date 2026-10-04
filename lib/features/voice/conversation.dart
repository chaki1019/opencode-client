import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../l10n/l10n.dart';
import '../ads/ads_providers.dart';
import '../chat/chat_providers.dart';
import '../chat/composer.dart';
import '../chat/composer_providers.dart';
import '../chat/prompt_providers.dart';
import '../live/live_providers.dart';
import '../settings/haptics.dart';
import 'speakable.dart';
import 'speech.dart';

/// Whether conversation mode is on for a session.
class ConversationActiveNotifier extends Notifier<bool> {
  ConversationActiveNotifier(this.sessionId);

  final String sessionId;

  @override
  bool build() => false;

  void start() => state = true;

  void stop() => state = false;
}

final conversationActiveProvider = NotifierProvider.autoDispose
    .family<ConversationActiveNotifier, bool, String>(
      ConversationActiveNotifier.new,
    );

enum ConversationPhase {
  /// Starting up or asking for permissions.
  preparing,
  listening,
  sending,

  /// The agent is working on the instruction.
  waiting,

  /// The agent asks for a permission or an answer, which needs the screen.
  needsInput,
  speaking,

  /// Nothing was heard; waits for a tap to listen again.
  idle,

  /// Speech recognition can't be used.
  unavailable,
}

/// Hands-free loop shown in place of the input: listen to an instruction,
/// send it, wait for the agent, read the reply aloud, and listen again.
/// Runs only while the app is in front, and stops on its own when the
/// agent needs an answer on screen.
class ConversationPanel extends ConsumerStatefulWidget {
  const ConversationPanel({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends ConsumerState<ConversationPanel>
    with WidgetsBindingObserver {
  static const _poll = Duration(milliseconds: 400);

  /// How long to wait for the session to start running before taking the
  /// latest reply as the answer.
  static const _startTimeout = Duration(seconds: 20);

  var _phase = ConversationPhase.preparing;
  var _words = '';

  /// Bumped to cancel the running loop.
  var _run = 0;

  // Read up front: dispose() must not touch ref.
  late final SpeechInput _input;
  late final SpeechOutput _output;

  String get _sessionId => widget.session.id;

  @override
  void initState() {
    super.initState();
    _input = ref.read(speechInputProvider);
    _output = ref.read(speechOutputProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _run++;
    unawaited(_input.stop());
    unawaited(_output.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _close();
    }
  }

  void _close() =>
      ref.read(conversationActiveProvider(_sessionId).notifier).stop();

  void _set(ConversationPhase phase, {String? words}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      if (words != null) _words = words;
    });
  }

  String get _localeTag =>
      speechLocaleTag(Localizations.localeOf(context).languageCode);

  Future<void> _start() async {
    final run = ++_run;
    _set(ConversationPhase.preparing);
    if (!await _input.available()) {
      if (run == _run) _set(ConversationPhase.unavailable);
      return;
    }
    if (run == _run) await _loop(run);
  }

  /// Listens again after a pause, or after nothing was heard.
  Future<void> _listenAgain() async {
    final run = ++_run;
    await _output.stop();
    await _loop(run);
  }

  Future<void> _loop(int run) async {
    while (mounted && run == _run) {
      _set(ConversationPhase.listening, words: '');
      final heard = await _input.listen(
        localeTag: _localeTag,
        onPartial: (words) {
          if (run == _run) _set(ConversationPhase.listening, words: words);
        },
      );
      if (!mounted || run != _run) return;
      if (heard == null) {
        _set(ConversationPhase.idle);
        return;
      }

      _set(ConversationPhase.sending, words: heard);
      if (!await _send(heard) || !mounted || run != _run) {
        _set(ConversationPhase.idle);
        return;
      }

      _set(ConversationPhase.waiting);
      if (!await _waitForReply(run) || !mounted) return;

      final entries =
          ref.read(timelineProvider(_sessionId)).value?.items ?? const [];
      final l10n = context.l10n;
      final reply = speakableText(
        latestReplyText(entries),
        codeSkipped: l10n.speechCodeSkipped,
        truncated: l10n.speechTruncated,
      );
      if (reply.isNotEmpty) {
        _set(ConversationPhase.speaking);
        await _output.speak(reply, localeTag: _localeTag);
        if (!mounted || run != _run) return;
      }
    }
  }

  Future<bool> _send(String text) async {
    if (!await readyToSend(context, ref, widget.session)) return false;
    ref.read(hapticsProvider).play(HapticCue.send);
    final ok = await ref
        .read(pendingPromptsProvider(_sessionId).notifier)
        .send(text);
    if (ok) unawaited(ref.read(messageQuotaProvider.notifier).recordSent());
    return ok;
  }

  /// Waits until the session has run and gone idle again. Shows that the
  /// agent needs input while a permission or question is pending. False
  /// when the loop was cancelled meanwhile.
  Future<bool> _waitForReply(int run) async {
    var sawBusy = false;
    final started = DateTime.now();
    while (true) {
      await Future<void>.delayed(_poll);
      if (!mounted || run != _run) return false;
      final busy = ref.read(activeSessionsProvider).contains(_sessionId);
      final asking =
          (ref.read(permissionsProvider(_sessionId)).value?.isNotEmpty ??
              false) ||
          (ref.read(formsProvider(widget.session)).value?.isNotEmpty ?? false);
      _set(asking ? ConversationPhase.needsInput : ConversationPhase.waiting);
      if (busy) {
        sawBusy = true;
      } else if (!asking &&
          (sawBusy || DateTime.now().difference(started) > _startTimeout)) {
        return true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, label) = switch (_phase) {
      ConversationPhase.preparing => (
        Icons.graphic_eq_rounded,
        l10n.conversationPreparing,
      ),
      ConversationPhase.listening => (
        Icons.mic_rounded,
        l10n.conversationListening,
      ),
      ConversationPhase.sending => (
        Icons.arrow_upward_rounded,
        l10n.conversationSending,
      ),
      ConversationPhase.waiting => (
        Icons.hourglass_top_rounded,
        l10n.conversationWaiting,
      ),
      ConversationPhase.needsInput => (
        Icons.front_hand_outlined,
        l10n.conversationNeedsInput,
      ),
      ConversationPhase.speaking => (
        Icons.volume_up_rounded,
        l10n.conversationSpeaking,
      ),
      ConversationPhase.idle => (Icons.mic_none_rounded, l10n.conversationIdle),
      ConversationPhase.unavailable => (
        Icons.mic_off_outlined,
        l10n.conversationUnavailable,
      ),
    };
    final canListen =
        _phase == ConversationPhase.idle ||
        _phase == ConversationPhase.speaking;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: DecoratedBox(
          key: const Key('conversation-panel'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        key: const Key('conversation-phase'),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (_words.isNotEmpty &&
                          (_phase == ConversationPhase.listening ||
                              _phase == ConversationPhase.sending))
                        Text(
                          _words,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canListen)
                  IconButton(
                    key: const Key('conversation-listen'),
                    tooltip: l10n.conversationListen,
                    onPressed: _listenAgain,
                    icon: const Icon(Icons.mic_rounded),
                  ),
                if (_phase == ConversationPhase.listening)
                  IconButton(
                    key: const Key('conversation-done'),
                    tooltip: l10n.conversationDoneSpeaking,
                    onPressed: () => unawaited(_input.stop()),
                    icon: const Icon(Icons.check_rounded),
                  ),
                IconButton.filledTonal(
                  key: const Key('conversation-close'),
                  tooltip: l10n.conversationEnd,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
