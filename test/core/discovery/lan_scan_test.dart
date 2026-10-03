import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/discovery/lan_scan.dart';
import 'package:opencode_mobile/core/discovery/server_discovery.dart';

void main() {
  group('looksLikeOpencodeHealth', () {
    test('accepts the v2 health body', () {
      expect(looksLikeOpencodeHealth(200, null, '{"healthy":true}'), isTrue);
    });

    test('accepts a password-protected server', () {
      expect(
        looksLikeOpencodeHealth(401, 'Basic realm="Secure Area"', ''),
        isTrue,
      );
    });

    test('rejects other services', () {
      expect(looksLikeOpencodeHealth(200, null, '<html></html>'), isFalse);
      expect(looksLikeOpencodeHealth(200, null, '{"ok":true}'), isFalse);
      expect(looksLikeOpencodeHealth(401, 'Bearer', ''), isFalse);
      expect(looksLikeOpencodeHealth(404, null, ''), isFalse);
    });
  });

  test('scans the /24 of private addresses, skipping this device', () {
    final targets = lanScanTargets([
      InternetAddress('192.168.1.20'),
      InternetAddress('127.0.0.1'),
      InternetAddress('100.64.0.5'),
    ]).map((a) => a.address);
    expect(targets, hasLength(253));
    expect(targets, contains('192.168.1.1'));
    expect(targets, contains('192.168.1.254'));
    expect(targets, isNot(contains('192.168.1.20')));
  });

  test('reports each server that answers and then finishes', () async {
    final probed = <Uri>[];
    final discovery = LanScanDiscovery(
      concurrency: 4,
      localAddresses: () async => [InternetAddress('10.0.0.2')],
      probe: (url) async {
        probed.add(url);
        return url.host == '10.0.0.7';
      },
    );
    final emitted = await discovery.watch().toList();
    expect(probed, hasLength(253));
    expect(probed.first.path, '/api/health');
    expect(emitted.last, const [
      DiscoveredServer(name: 'opencode-4096', baseUrl: 'http://10.0.0.7:4096'),
    ]);
  });

  test('merges mDNS and scan results and ends scanning', () async {
    final browse = StreamController<List<DiscoveredServer>>();
    final scan = StreamController<List<DiscoveredServer>>();
    const server = DiscoveredServer(
      name: 'opencode-4096',
      baseUrl: 'http://10.0.0.7:4096',
    );
    final snapshots = <DiscoverySnapshot>[];
    final sub = mergeDiscoveries(
      browse: browse.stream,
      scan: scan.stream,
    ).listen(snapshots.add);

    browse.add(const [server]);
    scan.add(const [server]);
    await scan.close();
    await pumpEventQueue();

    expect(snapshots.first.scanning, isTrue);
    expect(snapshots.last.scanning, isFalse);
    expect(snapshots.last.servers, const [server]);
    await sub.cancel();
  });
}
