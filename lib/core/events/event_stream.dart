import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import 'server_event.dart';
import 'sse_parser.dart';

enum EventStreamStatus { connecting, connected, reconnecting, stopped }

typedef EventStreamOpener = Future<Stream<List<int>>> Function(
  CancelToken cancelToken,
);

/// Keeps one v2 event stream open for the whole app and fans events out.
///
/// The connection is retried with exponential backoff (250 ms doubling up
/// to 8 s, plus jitter); the backoff resets once a connection has stayed up
/// for 10 s. A connection that delivers nothing, not even a keep-alive, for
/// [heartbeatTimeout] is treated as dead and reopened.
class EventStream {
  EventStream({
    required this.open,
    this.heartbeatTimeout = const Duration(seconds: 45),
    Random? random,
  }) : _random = random ?? Random();

  final EventStreamOpener open;
  final Duration heartbeatTimeout;
  final Random _random;

  final _events = StreamController<ServerEvent>.broadcast();
  final _status = StreamController<EventStreamStatus>.broadcast();

  EventStreamStatus _current = EventStreamStatus.stopped;
  CancelToken? _cancel;
  Completer<void>? _connectionDone;
  bool _running = false;

  Stream<ServerEvent> get events => _events.stream;

  /// Emits on every status change. [EventStreamStatus.connected] after a
  /// reconnect means events may have been missed, so listeners resync.
  Stream<EventStreamStatus> get statusChanges => _status.stream;
  EventStreamStatus get status => _current;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  Future<void> stop() async {
    _running = false;
    _cancel?.cancel();
    if (_connectionDone?.isCompleted == false) _connectionDone!.complete();
    _setStatus(EventStreamStatus.stopped);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _status.close();
  }

  Future<void> _loop() async {
    var attempt = 0;
    var first = true;
    while (_running) {
      _setStatus(
        first ? EventStreamStatus.connecting : EventStreamStatus.reconnecting,
      );
      first = false;
      final startedAt = DateTime.now();
      final cancel = _cancel = CancelToken();
      try {
        final bytes = await open(cancel);
        if (!_running) break;
        _setStatus(EventStreamStatus.connected);
        await _consume(bytes, cancel);
      } catch (_) {
        // Fall through to reconnect.
      }
      if (!_running) break;
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 10)) {
        attempt = 0;
      }
      final backoffMs = min(8000, 250 * pow(2, attempt).toInt());
      attempt = min(attempt + 1, 6);
      await Future<void>.delayed(
        Duration(milliseconds: backoffMs + _random.nextInt(200)),
      );
    }
  }

  Future<void> _consume(Stream<List<int>> bytes, CancelToken cancel) async {
    final done = _connectionDone = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    Timer? watchdog;
    void armWatchdog() {
      watchdog?.cancel();
      watchdog = Timer(heartbeatTimeout, () {
        cancel.cancel('heartbeat timeout');
        finish();
      });
    }

    armWatchdog();
    // Any received bytes, including SSE comments, count as liveness.
    final tapped = bytes.map((chunk) {
      armWatchdog();
      return chunk;
    });
    final subscription = parseSse(tapped).listen(
      (message) {
        final event = ServerEvent.tryParse(message.data);
        if (event != null && !_events.isClosed) _events.add(event);
      },
      onError: (Object _) => finish(),
      onDone: finish,
      cancelOnError: true,
    );
    await done.future;
    watchdog?.cancel();
    // The parser is an async* generator, so an error that reaches it after
    // cancellation surfaces through the cancel() future instead of onError.
    // Typically that is the CancelToken's own "request cancelled"
    // DioException from stop() or the watchdog. The connection is being
    // dropped on purpose here, so any such error is an expected end.
    unawaited(subscription.cancel().catchError((Object _) {}));
  }

  void _setStatus(EventStreamStatus status) {
    if (_current == status) return;
    _current = status;
    if (!_status.isClosed) _status.add(status);
  }
}
