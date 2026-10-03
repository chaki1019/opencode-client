import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Sends crash reports (Firebase Crashlytics). Builds without Firebase, debug
/// builds and tests use [CrashReporter.none].
abstract class CrashReporter {
  const factory CrashReporter.none() = _NoCrashReporter;

  /// Whether this build sends reports at all; the settings switch is hidden
  /// otherwise.
  bool get available;

  /// Turns sending on or off. The choice is kept by Crashlytics itself, so it
  /// already applies at the next launch, before any Dart code runs. Turning
  /// it off also drops reports not sent yet.
  Future<void> setEnabled(bool on);
}

class _NoCrashReporter implements CrashReporter {
  const _NoCrashReporter();

  @override
  bool get available => false;

  @override
  Future<void> setEnabled(bool on) async {}
}

class _CrashlyticsReporter implements CrashReporter {
  _CrashlyticsReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  bool get available => true;

  @override
  Future<void> setEnabled(bool on) async {
    await _crashlytics.setCrashlyticsCollectionEnabled(on);
    if (!on) await _crashlytics.deleteUnsentReports();
  }
}

/// Starts Firebase and routes uncaught Flutter and Dart errors to
/// Crashlytics. Uses the push build settings' Firebase project, so a build
/// without them reports nothing. Never throws: a failure here must not keep
/// the app from starting.
Future<CrashReporter> startCrashReporting(FirebaseOptions? options) async {
  if (options == null || kDebugMode || kIsWeb) {
    return const CrashReporter.none();
  }
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    final crashlytics = FirebaseCrashlytics.instance;
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    return _CrashlyticsReporter(crashlytics);
  } catch (error) {
    debugPrint('Crash reporting is off: $error');
    return const CrashReporter.none();
  }
}
