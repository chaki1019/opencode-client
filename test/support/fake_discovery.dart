import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:opencode_mobile/core/discovery/server_discovery.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';

/// Discovery driven by the test. With [finished] it reports that list and
/// ends, like a completed scan; otherwise it stays open, like mDNS
/// browsing, and the test pushes lists into [controller].
class FakeDiscovery implements ServerDiscovery {
  FakeDiscovery({this.finished});

  final List<DiscoveredServer>? finished;
  final controller = StreamController<List<DiscoveredServer>>.broadcast();

  @override
  Stream<List<DiscoveredServer>> watch() {
    final result = finished;
    return result != null ? Stream.value(result) : controller.stream;
  }
}

/// Keeps widget tests off the real network: no mDNS, and a LAN scan that
/// finds nothing.
List<Override> get noDiscoveryOverrides => [
  serverDiscoveryProvider.overrideWithValue(FakeDiscovery()),
  lanScanProvider.overrideWithValue(FakeDiscovery(finished: const [])),
];
