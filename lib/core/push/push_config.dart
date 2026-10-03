import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time push settings, passed with
/// `--dart-define-from-file=push.env.json` (see docs/push-notifications.md).
/// A build without them has push turned off.
class PushConfig {
  const PushConfig({
    required this.relayUrl,
    required this.projectId,
    required this.senderId,
    required this.androidApiKey,
    required this.androidAppId,
    required this.iosApiKey,
    required this.iosAppId,
    required this.iosBundleId,
  });

  const PushConfig.fromEnvironment()
    : relayUrl = const String.fromEnvironment('PUSH_RELAY_URL'),
      projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      senderId = const String.fromEnvironment('FIREBASE_SENDER_ID'),
      androidApiKey = const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
      androidAppId = const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
      iosApiKey = const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
      iosAppId = const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
      iosBundleId = const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  final String relayUrl;
  final String projectId;
  final String senderId;
  final String androidApiKey;
  final String androidAppId;
  final String iosApiKey;
  final String iosAppId;
  final String iosBundleId;

  /// Firebase options for the running platform, or null when this build
  /// lacks them.
  FirebaseOptions? get firebaseOptions {
    if (projectId.isEmpty || senderId.isEmpty) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android when androidAppId.isNotEmpty => FirebaseOptions(
        apiKey: androidApiKey,
        appId: androidAppId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
      TargetPlatform.iOS when iosAppId.isNotEmpty => FirebaseOptions(
        apiKey: iosApiKey,
        appId: iosAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: iosBundleId,
      ),
      _ => null,
    };
  }

  bool get isConfigured =>
      relayUrl.isNotEmpty && firebaseOptions != null && !kIsWeb;

  /// `ios` or `android`, as the relay records it.
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}
