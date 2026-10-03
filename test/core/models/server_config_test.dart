import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/server_config.dart';

void main() {
  test('accepts http(s) URLs with a host, with or without a scheme', () {
    expect(ServerConfig.isValidBaseUrl('192.168.0.14:4096'), isTrue);
    expect(ServerConfig.isValidBaseUrl('http://devbox.local:4096/'), isTrue);
    expect(ServerConfig.isValidBaseUrl('https://example.com'), isTrue);
  });

  test('rejects malformed URLs', () {
    expect(ServerConfig.isValidBaseUrl('htt@://192.168.0.14:4096'), isFalse);
    expect(ServerConfig.isValidBaseUrl('ftp://192.168.0.14'), isFalse);
    expect(ServerConfig.isValidBaseUrl('http://'), isFalse);
  });
}
