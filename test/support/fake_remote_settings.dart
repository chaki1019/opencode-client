import 'dart:async';

import 'package:opencode_mobile/core/config/remote_settings.dart';

/// Remote Config as the console sets it; [push] is a change arriving while
/// the app runs.
class FakeRemoteSettings implements RemoteSettings {
  FakeRemoteSettings([Map<String, String> values = const {}])
    : _values = values;

  Map<String, String> _values;
  final _updates = StreamController<void>.broadcast();
  int refreshes = 0;

  @override
  bool get available => true;

  @override
  Map<String, String> get values => _values;

  @override
  Stream<void> get updates => _updates.stream;

  @override
  Future<void> refresh() async => refreshes++;

  void push(Map<String, String> values) {
    _values = values;
    _updates.add(null);
  }
}
