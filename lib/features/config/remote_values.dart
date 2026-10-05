import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/remote_settings.dart';

/// Overridden in main with Remote Config when the build has Firebase.
final remoteSettingsProvider = Provider<RemoteSettings>(
  (ref) => const RemoteSettings.none(),
);

/// The Remote Config parameters set in the console. Starts from the last
/// fetched values (kept by Remote Config across launches), fetches at launch
/// and on resume, and follows console changes while the app runs.
class RemoteValuesNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final settings = ref.watch(remoteSettingsProvider);
    if (!settings.available) return const {};
    final updates = settings.updates.listen((_) => _read(settings));
    final listener = AppLifecycleListener(onResume: () => _refresh(settings));
    ref.onDispose(() {
      updates.cancel();
      listener.dispose();
    });
    unawaited(_refresh(settings));
    return settings.values;
  }

  Future<void> _refresh(RemoteSettings settings) async {
    await settings.refresh();
    _read(settings);
  }

  void _read(RemoteSettings settings) {
    if (ref.mounted) state = settings.values;
  }
}

final remoteValuesProvider =
    NotifierProvider<RemoteValuesNotifier, Map<String, String>>(
      RemoteValuesNotifier.new,
    );
