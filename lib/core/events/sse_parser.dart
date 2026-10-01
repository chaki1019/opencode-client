import 'dart:async';
import 'dart:convert';

/// One dispatched Server-Sent Event.
class SseMessage {
  const SseMessage({this.event = 'message', required this.data, this.id});

  final String event;
  final String data;
  final String? id;
}

/// Incremental SSE parser (WHATWG event-stream format).
///
/// Lines may end in LF, CR or CRLF, and a CRLF may be split across chunks.
/// As a safeguard for proxies that drop the blank separator line, a new
/// `data:` line that starts a JSON value while data is already buffered is
/// treated as the start of a new event.
class SseParser {
  final _line = StringBuffer();
  bool _lastWasCr = false;

  String _event = 'message';
  final List<String> _data = [];
  String? _lastId;

  /// Feeds decoded text and returns the events it completed.
  List<SseMessage> add(String chunk) {
    final out = <SseMessage>[];
    for (var i = 0; i < chunk.length; i++) {
      final ch = chunk[i];
      if (ch == '\n') {
        if (_lastWasCr) {
          _lastWasCr = false;
          continue; // second half of CRLF
        }
        _takeLine(out);
      } else if (ch == '\r') {
        _lastWasCr = true;
        _takeLine(out);
        continue;
      } else {
        _line.write(ch);
      }
      _lastWasCr = false;
    }
    return out;
  }

  /// Flushes a trailing event when the stream ends without a blank line.
  List<SseMessage> close() {
    final out = <SseMessage>[];
    if (_line.isNotEmpty) _takeLine(out);
    _dispatch(out);
    return out;
  }

  void _takeLine(List<SseMessage> out) {
    final line = _line.toString();
    _line.clear();
    if (line.isEmpty) {
      _dispatch(out);
      return;
    }
    if (line.startsWith(':')) return; // comment / keep-alive

    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_data.isNotEmpty &&
            (value.startsWith('{') || value.startsWith('['))) {
          _dispatch(out);
        }
        _data.add(value);
      case 'id':
        if (!value.contains('\u0000')) _lastId = value;
      default:
        break; // `retry` and unknown fields are ignored
    }
  }

  void _dispatch(List<SseMessage> out) {
    if (_data.isNotEmpty) {
      out.add(SseMessage(event: _event, data: _data.join('\n'), id: _lastId));
    }
    _data.clear();
    _event = 'message';
  }
}

/// Decodes a byte stream into SSE messages.
Stream<SseMessage> parseSse(Stream<List<int>> bytes) async* {
  final parser = SseParser();
  await for (final text in bytes.cast<List<int>>().transform(
    const Utf8Decoder(allowMalformed: true),
  )) {
    for (final message in parser.add(text)) {
      yield message;
    }
  }
  for (final message in parser.close()) {
    yield message;
  }
}
