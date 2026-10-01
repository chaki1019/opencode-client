import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/events/sse_parser.dart';

List<String> data(List<SseMessage> messages) =>
    messages.map((m) => m.data).toList();

void main() {
  test('dispatches on blank lines and joins multi-line data', () {
    final parser = SseParser();
    final out = parser.add('event: update\nid: 7\ndata: a\ndata: b\n\n');
    expect(out.single.event, 'update');
    expect(out.single.id, '7');
    expect(out.single.data, 'a\nb');
  });

  test('handles CRLF split across chunks, CR-only lines and comments', () {
    final parser = SseParser();
    expect(parser.add(': keep-alive\r'), isEmpty);
    expect(parser.add('\ndata: {"x":1}\r'), isEmpty);
    final out = parser.add('\n\r\ndata: two\r\r');
    expect(data(out), ['{"x":1}', 'two']);
  });

  test('handles a value without a space and a field without a colon', () {
    final out = SseParser().add('data:tight\ndata\n\n');
    expect(out.single.data, 'tight\n');
  });

  test('starts a new event when a JSON data line follows buffered data', () {
    final out = SseParser().add('data: {"a":1}\ndata: {"b":2}\n\n');
    expect(data(out), ['{"a":1}', '{"b":2}']);
  });

  test('close flushes an unterminated event', () {
    final parser = SseParser();
    expect(parser.add('data: last'), isEmpty);
    expect(data(parser.close()), ['last']);
  });

  test('parseSse decodes UTF-8 split across byte chunks', () async {
    final bytes = utf8.encode('data: こんにちは\n\n');
    // Split inside a multi-byte character.
    final stream = Stream.fromIterable([bytes.sublist(0, 8), bytes.sublist(8)]);
    final out = await parseSse(stream).toList();
    expect(out.single.data, 'こんにちは');
  });
}
