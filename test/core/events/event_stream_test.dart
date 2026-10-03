import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
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

  // A stream that reports the CancelToken's cancellation as an error, the
  // way dio's response stream does.
  Future<Stream<List<int>>> openCancellable(CancelToken cancel) async {
    final controller = StreamController<List<int>>();
    cancel.whenCancel.then(controller.addError);
    return controller.stream;
  }

  test('stopping a live connection does not leak the cancel error', () async {
    final stream = EventStream(random: Random(0), open: openCancellable)
      ..start();
    await stream.statusChanges.firstWhere(
      (s) => s == EventStreamStatus.connected,
    );
    await stream.dispose();
    await pumpEventQueue();
    expect(stream.status, EventStreamStatus.stopped);
  });

  test('a heartbeat timeout does not leak the cancel error', () async {
    var opened = 0;
    final stream = EventStream(
      random: Random(0),
      heartbeatTimeout: const Duration(milliseconds: 100),
      open: (cancel) {
        opened++;
        return openCancellable(cancel);
      },
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(opened, greaterThanOrEqualTo(2));
    await stream.dispose();
    await pumpEventQueue();
  });

  test('disconnecting from a real dio event stream ends cleanly', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType('text', 'event-stream')
        ..bufferOutput = false
        ..write(': connected\n\n')
        ..flush();
    });
    final client = OpenCodeClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      username: 'opencode',
      password: '',
    );
    final stream = EventStream(
      random: Random(0),
      open: (cancel) => client.openEventStream(cancelToken: cancel),
    )..start();
    await stream.statusChanges.firstWhere(
      (s) => s == EventStreamStatus.connected,
    );
    await stream.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(stream.status, EventStreamStatus.stopped);
  });

  test('dropCancellation ends the stream on a cancel error only', () async {
    final cancelled = StreamController<List<int>>();
    final received = <Object>[];
    final done = Completer<void>();
    dropCancellation(cancelled.stream)
        .listen((_) {}, onError: received.add, onDone: done.complete);
    cancelled
      ..addError(
        DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: null,
        ),
      )
      ..close();
    await done.future;
    expect(received, isEmpty);

    final failed = StreamController<List<int>>();
    final errors = <Object>[];
    final sub = dropCancellation(failed.stream)
        .listen((_) {}, onError: errors.add);
    failed.addError(const SocketException('reset'));
    await pumpEventQueue();
    expect(errors.single, isA<SocketException>());
    await sub.cancel();
  });
}
