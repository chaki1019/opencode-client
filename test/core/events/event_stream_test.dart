import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/events/server_event.dart';

List<int> sse(Map<String, Object?> event) =>
    utf8.encode('data: ${jsonEncode(event)}\n\n');

void main() {
  test('emits parsed events and reconnects when the stream ends', () async {
    final connections = <StreamController<List<int>>>[];
    final stream = EventStream(
      random: Random(0),
      open: (_) async {
        final controller = StreamController<List<int>>();
        connections.add(controller);
        return controller.stream;
      },
    );
    final statuses = <EventStreamStatus>[];
    stream.statusChanges.listen(statuses.add);
    final events = <ServerEvent>[];
    stream.events.listen(events.add);

    stream.start();
    await pumpEventQueue();
    connections.single.add(
      sse({
        'type': 'session.idle',
        'data': {'sessionID': 's1'},
      }),
    );
    connections.single.add(utf8.encode('data: not json\n\n'));
    await pumpEventQueue();
    expect(events.single.type, 'session.idle');
    expect(events.single.sessionId, 's1');

    await connections.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(connections, hasLength(2));
    expect(statuses, [
      EventStreamStatus.connecting,
      EventStreamStatus.connected,
      EventStreamStatus.reconnecting,
      EventStreamStatus.connected,
    ]);

    await stream.dispose();
    expect(statuses.last, EventStreamStatus.stopped);
  });

  test('reopens a connection that goes silent past the heartbeat', () async {
    var opened = 0;
    final stream = EventStream(
      random: Random(0),
      heartbeatTimeout: const Duration(milliseconds: 100),
      open: (_) async {
        opened++;
        return StreamController<List<int>>().stream; // never sends
      },
    );
    stream.start();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(opened, greaterThanOrEqualTo(2));
    await stream.dispose();
  });

  test('retries after a failed open', () async {
    var attempts = 0;
    final stream = EventStream(
      random: Random(0),
      open: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('refused');
        return StreamController<List<int>>().stream;
      },
    );
    stream.start();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(attempts, 2);
    expect(stream.status, EventStreamStatus.connected);
    await stream.dispose();
  });
}
