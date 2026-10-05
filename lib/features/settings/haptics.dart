import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/server_event.dart';
import '../../core/storage/settings_store.dart';
import '../live/live_providers.dart';
import 'settings_providers.dart';

/// The moments the app marks with a short vibration. Kept few and light so
/// they stay meaningful.
enum HapticCue {
  /// A message was sent.
  send,

  /// The AI started writing its reply. Only at the strong level.
  replyStarted,

  /// The AI finished its reply.
  replyDone,

  /// The AI is waiting on a permission or a question.
  attention,

  /// A run or an action failed.
  failure,

  /// A long-press menu opened.
  longPress,

  /// A swipe crossed the point where letting go acts.
  swipeThreshold,
}

/// Plays [HapticCue]s at the level chosen in Settings.
class Haptics {
  const Haptics({required this.level});

  final HapticsLevel level;

  Future<void> play(HapticCue cue) async {
    if (level == HapticsLevel.off) return;
    final strong = level == HapticsLevel.strong;
    if (cue == HapticCue.replyStarted && !strong) return;
    switch (cue) {
      case HapticCue.send:
      case HapticCue.replyStarted:
      case HapticCue.swipeThreshold:
        await (strong
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick());
      case HapticCue.replyDone:
        await (strong
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.mediumImpact());
      case HapticCue.attention:
        await HapticFeedback.heavyImpact();
        if (strong) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.heavyImpact();
        }
      case HapticCue.failure:
        // Several quick taps, so it does not read as a finished reply.
        for (var i = 0; i < (strong ? 3 : 2); i++) {
          if (i > 0) {
            await Future<void>.delayed(const Duration(milliseconds: 120));
          }
          await HapticFeedback.heavyImpact();
        }
      case HapticCue.longPress:
        // Android widgets already vibrate on long press themselves.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await (strong
              ? HapticFeedback.heavyImpact()
              : HapticFeedback.mediumImpact());
        }
    }
  }
}

final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(level: ref.watch(settingsProvider.select((s) => s.haptics))),
);

/// Decides which cue, if any, a server event about one session deserves.
/// A run's end is marked once, even when the server sends both a result and
/// `session.idle`. A run the user stopped gets no cue. The start of a reply
/// is marked at the first text of each run, not at every message in it.
class SessionCues {
  SessionCues(this.sessionId, {required bool running})
    : _ended = !running,
      _writing = running;

  final String sessionId;
  bool _ended;
  bool _writing;

  HapticCue? onEvent(ServerEvent event) {
    final asked = waitingRequestAdded(event);
    if (asked != null) {
      return asked.$2 == sessionId ? HapticCue.attention : null;
    }
    if (event.sessionId != sessionId) return null;
    if (event.isExecutionStarted) {
      _ended = false;
      _writing = false;
      return null;
    }
    if (event.type == 'session.text.started') {
      if (_writing) return null;
      _writing = true;
      return HapticCue.replyStarted;
    }
    if (!event.isExecutionTerminal || _ended) return null;
    _ended = true;
    return switch (event.type) {
      'session.execution.failed' => HapticCue.failure,
      'session.execution.interrupted' => null,
      _ => HapticCue.replyDone,
    };
  }
}

/// Marks reply completion, permission requests and failures of one session
/// while something watches it (the open chat).
final sessionHapticsProvider = Provider.autoDispose.family<void, String>((
  ref,
  sessionId,
) {
  final cues = SessionCues(
    sessionId,
    running: ref.read(activeSessionsProvider).contains(sessionId),
  );
  listenToServerEvents(
    ref,
    onEvent: (event) {
      final cue = cues.onEvent(event);
      if (cue != null) ref.read(hapticsProvider).play(cue);
    },
  );
});
