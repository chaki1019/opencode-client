import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:opencode_mobile/core/discovery/server_discovery.dart';

void main() {
  test('keeps OpenCode services and prefers their IPv4 address', () {
    final servers = discoveredServersFrom([
      Service(
        name: 'opencode-4096',
        type: '_http._tcp',
        host: 'opencode.local.',
        port: 4096,
        addresses: [
          InternetAddress('fe80::1'),
          InternetAddress('192.168.1.20'),
        ],
      ),
      const Service(name: 'Office Printer', host: 'printer.local', port: 80),
    ]);
    expect(servers, const [
      DiscoveredServer(
        name: 'opencode-4096',
        baseUrl: 'http://192.168.1.20:4096',
      ),
    ]);
  });

  test('falls back to the host name and skips unresolved services', () {
    final servers = discoveredServersFrom(const [
      Service(name: 'opencode-5000', host: 'devbox.local.', port: 5000),
      Service(name: 'opencode-6000'),
    ]);
    expect(servers.single.baseUrl, 'http://devbox.local:5000');
  });

  test('lists a server announced twice once', () {
    const service = Service(name: 'opencode-4096', host: 'a.local', port: 4096);
    expect(discoveredServersFrom(const [service, service]), hasLength(1));
  });
}
