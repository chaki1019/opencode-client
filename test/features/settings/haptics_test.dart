import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/events/server_event.dart';
import 'package:opencode_mobile/core/storage/settings_store.dart';
import 'package:opencode_mobile/features/settings/haptics.dart';

ServerEvent event(String type, [String session = 's1']) =>
    ServerEvent(type: type, data: {'sessionID': session});

void main() {
  group('SessionCues', () {
    test('a finished run is marked once', () {
      final cues = SessionCues('s1', running: false);
      expect(cues.onEvent(event('session.execution.started')), isNull);
      expect(
        cues.onEvent(event('session.execution.succeeded')),
        HapticCue.replyDone,
      );
      expect(cues.onEvent(event('session.idle')), isNull);
    });

    test('a run already going when the chat opens is marked', () {
      final cues = SessionCues('s1', running: true);
      expect(cues.onEvent(event('session.idle')), HapticCue.replyDone);
    });

    test('an idle session is not marked by a stray idle event', () {
      final cues = SessionCues('s1', running: false);
      expect(cues.onEvent(event('session.idle')), isNull);
    });

    test('failures, stops and permission requests', () {
      final cues = SessionCues('s1', running: true);
      expect(
        cues.onEvent(event('session.execution.failed')),
        HapticCue.failure,
      );
      cues.onEvent(event('session.execution.started'));
      expect(cues.onEvent(event('session.execution.interrupted')), isNull);
      expect(
        cues.onEvent(
          const ServerEvent(
            type: 'permission.v2.asked',
            data: {'id': 'p1', 'sessionID': 's1'},
          ),
        ),
        HapticCue.attention,
      );
    });

    test('the start of a reply is marked once per run', () {
      final cues = SessionCues('s1', running: false);
      cues.onEvent(event('session.execution.started'));
      expect(
        cues.onEvent(event('session.text.started')),
        HapticCue.replyStarted,
      );
      expect(cues.onEvent(event('session.text.started')), isNull);
      cues.onEvent(event('session.execution.succeeded'));
      cues.onEvent(event('session.execution.started'));
      expect(
        cues.onEvent(event('session.text.started')),
        HapticCue.replyStarted,
      );
    });

    test('a run already writing when the chat opens is not marked', () {
      final cues = SessionCues('s1', running: true);
      expect(cues.onEvent(event('session.text.started')), isNull);
    });

    test('other sessions are ignored', () {
      final cues = SessionCues('s1', running: true);
      expect(cues.onEvent(event('session.idle', 's2')), isNull);
      expect(
        cues.onEvent(
          const ServerEvent(
            type: 'permission.v2.asked',
            data: {'id': 'p1', 'sessionID': 's2'},
          ),
        ),
        isNull,
      );
    });
  });

  group('Haptics', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late List<Object?> played;

    setUp(() {
      played = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              played.add(call.arguments);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('plays when enabled', () async {
      await const Haptics(level: HapticsLevel.light).play(HapticCue.replyDone);
      expect(played, ['HapticFeedbackType.mediumImpact']);
    });

    test('stays silent when turned off', () async {
      await const Haptics(level: HapticsLevel.off).play(HapticCue.failure);
      expect(played, isEmpty);
    });

    test('the start of a reply plays only at the strong level', () async {
      await const Haptics(level: HapticsLevel.light)
          .play(HapticCue.replyStarted);
      expect(played, isEmpty);
      await const Haptics(level: HapticsLevel.strong)
          .play(HapticCue.replyStarted);
      expect(played, ['HapticFeedbackType.lightImpact']);
    });

    test('the strong level plays a step stronger', () async {
      await const Haptics(level: HapticsLevel.strong).play(HapticCue.send);
      await const Haptics(level: HapticsLevel.strong).play(HapticCue.replyDone);
      expect(played, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });
  });
}
