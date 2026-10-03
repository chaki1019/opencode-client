import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'server_discovery.dart';

/// The port `opencode serve` tries first.
const defaultOpencodePort = 4096;

/// Whether a `/api/health` response came from an OpenCode v2 server.
///
/// v2 answers `{"healthy": true}`. A server with a password rejects the
/// unauthenticated probe with 401 and a Basic challenge, which still shows
/// something is listening that wants OpenCode's credentials.
bool looksLikeOpencodeHealth(
  int statusCode,
  String? wwwAuthenticate,
  String body,
) {
  if (statusCode == 401) {
    return wwwAuthenticate?.toLowerCase().startsWith('basic') ?? false;
  }
  if (statusCode != 200) return false;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map && decoded['healthy'] == true;
  } on FormatException {
    return false;
  }
}

bool _isPrivate(InternetAddress address) {
  final b = address.rawAddress;
  if (b.length != 4) return false;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

/// The other addresses in the /24 networks of this device's private IPv4
/// addresses. Phones on Wi-Fi are almost always on a /24, and scanning a
/// wider range would take too long to be useful.
List<InternetAddress> lanScanTargets(Iterable<InternetAddress> own) {
  final targets = <String, InternetAddress>{};
  final ownSet = {for (final a in own) a.address};
  for (final address in own) {
    if (!_isPrivate(address)) continue;
    final b = address.rawAddress;
    for (var host = 1; host <= 254; host++) {
      final candidate = '${b[0]}.${b[1]}.${b[2]}.$host';
      if (ownSet.contains(candidate)) continue;
      targets.putIfAbsent(candidate, () => InternetAddress(candidate));
    }
  }
  return targets.values.toList();
}

/// Finds OpenCode servers by asking every address on the local /24 for
/// `/api/health`. Unlike mDNS this needs nothing on the server side, but
/// only finds servers on [port] that listen on the network (for example
/// `opencode serve --hostname 0.0.0.0`).
class LanScanDiscovery implements ServerDiscovery {
  LanScanDiscovery({
    this.port = defaultOpencodePort,
    this.concurrency = 32,
    Future<List<InternetAddress>> Function()? localAddresses,
    Future<bool> Function(Uri healthUrl)? probe,
  }) : _localAddresses = localAddresses ?? _deviceAddresses,
       _probe = probe ?? _httpProbe;

  final int port;
  final int concurrency;
  final Future<List<InternetAddress>> Function() _localAddresses;
  final Future<bool> Function(Uri healthUrl) _probe;

  static Future<List<InternetAddress>> _deviceAddresses() async => [
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      ...interface.addresses,
  ];

  static Future<bool> _httpProbe(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1500);
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      return looksLikeOpencodeHealth(
        response.statusCode,
        response.headers.value(HttpHeaders.wwwAuthenticateHeader),
        body,
      );
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Emits the servers found so far after each hit, and closes once every
  /// address has been tried.
  @override
  Stream<List<DiscoveredServer>> watch() {
    var cancelled = false;
    late final StreamController<List<DiscoveredServer>> controller;
    controller = StreamController(
      onListen: () async {
        final found = <DiscoveredServer>[];
        try {
          final targets = lanScanTargets(await _localAddresses());
          var next = 0;
          Future<void> worker() async {
            while (!cancelled && next < targets.length) {
              final host = targets[next++].address;
              final hit = await _probe(
                Uri.parse('http://$host:$port/api/health'),
              );
              if (hit && !cancelled) {
                found.add(
                  DiscoveredServer(
                    name: '$opencodeServicePrefix$port',
                    baseUrl: 'http://$host:$port',
                  ),
                );
                controller.add(List.of(found));
              }
            }
          }

          controller.add(const []);
          await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
        } catch (e) {
          debugPrint('LAN scan failed: $e');
        } finally {
          if (!controller.isClosed) await controller.close();
        }
      },
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }
}
