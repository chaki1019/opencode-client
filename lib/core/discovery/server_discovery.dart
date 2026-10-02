import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

/// An OpenCode server announced on the local network.
@immutable
class DiscoveredServer {
  const DiscoveredServer({required this.name, required this.baseUrl});

  /// The announced service name, e.g. `opencode-4096`.
  final String name;
  final String baseUrl;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer &&
      other.name == name &&
      other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(name, baseUrl);
}

/// Finds OpenCode servers on the local network.
///
/// `opencode serve --mdns` (or `server.mdns` in the config) announces an
/// `_http._tcp` service named `opencode-<port>`. Every instance uses the
/// same host name (`opencode.local` unless `--mdns-domain` is set), so the
/// server's IP address is preferred over that name.
abstract class ServerDiscovery {
  /// Emits the servers found so far each time the set changes. Browsing
  /// stops when the subscription is cancelled.
  Stream<List<DiscoveredServer>> watch();
}

const opencodeServiceType = '_http._tcp';
const opencodeServicePrefix = 'opencode-';

/// Keeps the OpenCode services from an mDNS browse and turns each into a
/// connectable URL. Services that are not resolved yet are skipped.
List<DiscoveredServer> discoveredServersFrom(Iterable<nsd.Service> services) {
  final byUrl = <String, DiscoveredServer>{};
  for (final service in services) {
    final name = service.name;
    final port = service.port;
    if (name == null || !name.startsWith(opencodeServicePrefix)) continue;
    if (port == null) continue;
    final ipv4 = service.addresses
        ?.where((a) => a.type == InternetAddressType.IPv4)
        .firstOrNull;
    var host = ipv4?.address ?? service.host;
    if (host == null || host.isEmpty) continue;
    while (host!.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    final baseUrl = 'http://$host:$port';
    byUrl.putIfAbsent(
      baseUrl,
      () => DiscoveredServer(name: name, baseUrl: baseUrl),
    );
  }
  return byUrl.values.toList()..sort((a, b) => a.baseUrl.compareTo(b.baseUrl));
}

/// Browses with the platform's service discovery (NSD on Android, Bonjour
/// on iOS).
class NsdServerDiscovery implements ServerDiscovery {
  @override
  Stream<List<DiscoveredServer>> watch() {
    nsd.Discovery? discovery;
    var cancelled = false;
    late final StreamController<List<DiscoveredServer>> controller;

    void emit() {
      final current = discovery;
      if (current != null && !controller.isClosed) {
        controller.add(discoveredServersFrom(current.services));
      }
    }

    controller = StreamController(
      onListen: () async {
        try {
          final started = await nsd.startDiscovery(
            opencodeServiceType,
            ipLookupType: nsd.IpLookupType.v4,
          );
          if (cancelled) {
            await nsd.stopDiscovery(started);
            return;
          }
          discovery = started..addListener(emit);
          emit();
        } catch (e) {
          // Browsing is a convenience: without it the user still types the
          // URL, so a platform failure shows as "nothing found".
          debugPrint('Server discovery failed: $e');
          if (!controller.isClosed) controller.add(const []);
        }
      },
      onCancel: () async {
        cancelled = true;
        final current = discovery;
        discovery = null;
        if (current != null) {
          current.removeListener(emit);
          await nsd.stopDiscovery(current);
        }
      },
    );
    return controller.stream;
  }
}
