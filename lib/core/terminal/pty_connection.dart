import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// A message from the terminal WebSocket.
sealed class PtyFrame {
  const PtyFrame();
}

/// Terminal output.
class PtyOutput extends PtyFrame {
  const PtyOutput(this.text);
  final String text;
}

/// The server's position in the output stream.
class PtyCursor extends PtyFrame {
  const PtyCursor(this.cursor);
  final int cursor;
}

/// Text frames are output. Binary frames that start with a zero byte carry
/// `{"cursor": n}`; anything else is ignored.
PtyFrame? decodePtyFrame(Object? message) {
  if (message is String) return PtyOutput(message);
  if (message is List<int> && message.isNotEmpty && message.first == 0) {
    try {
      final json = jsonDecode(utf8.decode(message.sublist(1)));
      final cursor = json is Map ? json['cursor'] : null;
      if (cursor is int && cursor >= 0) return PtyCursor(cursor);
    } on FormatException {
      return null;
    }
  }
  return null;
}

enum PtyConnectionState { connecting, open, closed, failed }

typedef SocketConnector = WebSocketChannel Function(
  Uri uri,
  Map<String, String> headers,
);

WebSocketChannel _connect(Uri uri, Map<String, String> headers) =>
    IOWebSocketChannel.connect(
      uri,
      headers: headers,
      pingInterval: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 10),
    );

/// One terminal's WebSocket. Keystrokes go up as text frames; output comes
/// down as text. Window size is set over HTTP, not here.
///
/// The connection tracks how much output it has seen, so [connect] after a
/// drop resumes where it left off instead of replaying everything.
class PtyConnection {
  PtyConnection({
    required this.uriFor,
    required this.headers,
    SocketConnector? connector,
  }) : _connector = connector ?? _connect;

  /// Builds the socket address for a starting cursor.
  final Uri Function(int cursor) uriFor;
  final Map<String, String> headers;
  final SocketConnector _connector;

  final _output = StreamController<String>.broadcast();
  final _state = StreamController<PtyConnectionState>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  PtyConnectionState _current = PtyConnectionState.closed;
  bool _disposed = false;

  int cursor = 0;

  Stream<String> get output => _output.stream;
  Stream<PtyConnectionState> get stateChanges => _state.stream;
  PtyConnectionState get state => _current;

  void _set(PtyConnectionState state) {
    if (_disposed || state == _current) return;
    _current = state;
    _state.add(state);
  }

  Future<void> connect() async {
    if (_disposed) return;
    await _subscription?.cancel();
    _set(PtyConnectionState.connecting);
    final channel = _connector(uriFor(cursor), headers);
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) => _set(PtyConnectionState.failed),
      onDone: () => _set(
        channel.closeCode == status.normalClosure
            ? PtyConnectionState.closed
            : PtyConnectionState.failed,
      ),
    );
    try {
      await channel.ready;
      if (identical(channel, _channel)) _set(PtyConnectionState.open);
    } catch (_) {
      if (identical(channel, _channel)) _set(PtyConnectionState.failed);
    }
  }

  void _onMessage(Object? message) {
    switch (decodePtyFrame(message)) {
      case PtyOutput(:final text):
        cursor += text.length;
        if (!_disposed) _output.add(text);
      case PtyCursor(cursor: final value):
        cursor = value;
      case null:
        break;
    }
  }

  /// Sends keystrokes. Dropped while not connected.
  void send(String data) {
    if (_current == PtyConnectionState.open) _channel?.sink.add(data);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _channel?.sink.close(status.normalClosure);
    await _output.close();
    await _state.close();
  }
}
