import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Values the owner changes without a new build, from Firebase Remote
/// Config: the minimum app versions and the rewarded-ad switches
/// (docs/force-update.md, docs/ads.md). Builds without Firebase and tests
/// use [RemoteSettings.none].
abstract class RemoteSettings {
  const factory RemoteSettings.none() = _NoRemoteSettings;

  /// Whether this build reads Remote Config at all.
  bool get available;

  /// The parameters set in the console, as last fetched; empty until the
  /// first fetch ever succeeds. Unset parameters are left out, so the
  /// app's own values apply.
  Map<String, String> get values;

  /// Fires when new values were activated: a console change pushed while
  /// the app runs.
  Stream<void> get updates;

  /// Fetches and activates the latest values. Never throws: a failure
  /// keeps the last ones.
  Future<void> refresh();
}

class _NoRemoteSettings implements RemoteSettings {
  const _NoRemoteSettings();

  @override
  bool get available => false;

  @override
  Map<String, String> get values => const {};

  @override
  Stream<void> get updates => const Stream.empty();

  @override
  Future<void> refresh() async {}
}

class _FirebaseRemoteSettings implements RemoteSettings {
  _FirebaseRemoteSettings(this._config);

  final FirebaseRemoteConfig _config;

  @override
  bool get available => true;

  @override
  Map<String, String> get values => {
    for (final MapEntry(:key, :value) in _config.getAll().entries)
      if (value.source == ValueSource.valueRemote) key: value.asString(),
  };

  @override
  Stream<void> get updates => _config.onConfigUpdated
      .asyncMap((_) => _config.activate())
      .handleError((Object error) {
        // Real-time updates are a bonus; the fetch on launch and resume
        // still applies the change.
        debugPrint('Remote Config updates are off: $error');
      });

  @override
  Future<void> refresh() async {
    try {
      await _config.fetchAndActivate();
    } catch (error) {
      debugPrint('Remote Config fetch failed: $error');
    }
  }
}

/// Starts Remote Config on the push build settings' Firebase project. A build
/// without them reads nothing. Never throws.
Future<RemoteSettings> startRemoteSettings(FirebaseOptions? options) async {
  if (options == null || kIsWeb) return const RemoteSettings.none();
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    final config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // The app asks again on resume at most this often; console changes
        // also arrive in real time while it runs.
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 30),
      ),
    );
    return _FirebaseRemoteSettings(config);
  } catch (error) {
    debugPrint('Remote Config is off: $error');
    return const RemoteSettings.none();
  }
}

/// The Remote Config parameters, in the shape of the relay's
/// `/v1/app-version` response, so both feed the same parsers.
Map<String, Object?> remoteSettingsJson(Map<String, String> values) {
  String? text(String key) {
    final value = values[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool? flag(String key) => switch (text(key)?.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  int? count(String key) => int.tryParse(text(key) ?? '');

  // Remote Config resolves platform differences with conditions, so one
  // value serves whichever platform asks. The store pages are fixed in the
  // app, so only the version comes from here.
  final minimum = {'minimum': text('app_version')};
  return {
    'ios': minimum,
    'android': minimum,
    'ads': {
      'rewarded': flag('rewarded_ads_enabled'),
      'freeMessages': count('daily_free_messages'),
      'messagesPerReward': count('ads_messages_per_reward'),
    },
  };
}
