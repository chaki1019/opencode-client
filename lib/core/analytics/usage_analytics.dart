import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Sends usage statistics (Firebase Analytics): installs, active days and
/// which screens are opened, to see how many users stay. Never tied to the
/// advertising ID; the native settings that keep it so are in Info.plist and
/// AndroidManifest.xml. Builds without Firebase, debug builds and tests use
/// [UsageAnalytics.none].
abstract class UsageAnalytics {
  const factory UsageAnalytics.none() = _NoUsageAnalytics;

  /// Whether this build sends statistics at all; the settings switch is
  /// hidden otherwise.
  bool get available;

  /// Logs a screen view for each page the app's navigator shows, or null when
  /// nothing is sent.
  NavigatorObserver? get observer;

  /// Turns sending on or off. Analytics keeps the choice itself, so it
  /// already applies at the next launch, before any Dart code runs.
  Future<void> setEnabled(bool on);
}

class _NoUsageAnalytics implements UsageAnalytics {
  const _NoUsageAnalytics();

  @override
  bool get available => false;

  @override
  NavigatorObserver? get observer => null;

  @override
  Future<void> setEnabled(bool on) async {}
}

class _FirebaseUsageAnalytics implements UsageAnalytics {
  _FirebaseUsageAnalytics(this._analytics)
    : observer = FirebaseAnalyticsObserver(analytics: _analytics);

  final FirebaseAnalytics _analytics;

  @override
  bool get available => true;

  @override
  final NavigatorObserver observer;

  @override
  Future<void> setEnabled(bool on) =>
      _analytics.setAnalyticsCollectionEnabled(on);
}

/// Starts Analytics on the push build settings' Firebase project, so a build
/// without them sends nothing. Never throws: a failure here must not keep the
/// app from starting.
Future<UsageAnalytics> startUsageAnalytics(FirebaseOptions? options) async {
  if (options == null || kDebugMode || kIsWeb) {
    return const UsageAnalytics.none();
  }
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    final analytics = FirebaseAnalytics.instance;
    // Also set as the native defaults; repeated here so a stale stored
    // consent can never allow ad use.
    await analytics.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    return _FirebaseUsageAnalytics(analytics);
  } catch (error) {
    debugPrint('Usage analytics is off: $error');
    return const UsageAnalytics.none();
  }
}
