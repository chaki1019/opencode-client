import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/terminal/pty_connection.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// An in-memory socket: [incoming] feeds the client, [sent] records what the
/// client wrote.
class FakeSocket with StreamChannelMixin<dynamic> implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final sent = <dynamic>[];
  int? code;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  late final WebSocketSink sink = _FakeSink(this);

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => code;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.socket);
  final FakeSocket socket;

  @override
  void add(dynamic data) => socket.sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done => Future.value();
}

void main() {
  test('decodes output text and cursor metadata frames', () {
    expect((decodePtyFrame('ls\r\n') as PtyOutput).text, 'ls\r\n');
    final meta = [0, ...utf8.encode('{"cursor":12345}')];
    expect((decodePtyFrame(meta) as PtyCursor).cursor, 12345);
    expect(decodePtyFrame([1, 2, 3]), isNull);
    expect(decodePtyFrame([0, ...utf8.encode('nope')]), isNull);
  });

  test('streams output, sends input and resumes from its cursor', () async {
    final sockets = <FakeSocket>[];
    final uris = <Uri>[];
    final connection = PtyConnection(
      uriFor: (cursor) =>
          Uri.parse('ws://host/api/pty/p/connect?cursor=$cursor'),
      headers: const {'Authorization': 'Basic x'},
      connector: (uri, headers) {
        expect(headers['Authorization'], 'Basic x');
        uris.add(uri);
        return FakeSocket()..let(sockets.add);
      },
    );
    final output = <String>[];
    connection.output.listen(output.add);

    await connection.connect();
    expect(connection.state, PtyConnectionState.open);
    sockets.single.incoming.add('a🚀é');
    await pumpEventQueue();
    expect(output, ['a🚀é']);
    expect(connection.cursor, 4); // UTF-16 code units

    connection.send('echo hi\r');
    expect(sockets.single.sent, ['echo hi\r']);

    // The server reports its position, then the socket drops.
    sockets.single.incoming.add([0, ...utf8.encode('{"cursor":40}')]);
    sockets.single.code = 1006;
    await sockets.single.incoming.close();
    await pumpEventQueue();
    expect(connection.state, PtyConnectionState.failed);

    await connection.connect();
    expect(uris.last.queryParameters['cursor'], '40');
    await connection.dispose();
  });

  test('a normal close is reported as closed', () async {
    final socket = FakeSocket()..code = 1000;
    final connection = PtyConnection(
      uriFor: (_) => Uri.parse('ws://host'),
      headers: const {},
      connector: (_, _) => socket,
    );
    await connection.connect();
    await socket.incoming.close();
    await pumpEventQueue();
    expect(connection.state, PtyConnectionState.closed);
    await connection.dispose();
  });
}

extension<T> on T {
  T let(void Function(T) f) {
    f(this);
    return this;
  }
}
