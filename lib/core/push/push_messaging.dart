import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_message.dart';

/// The platform push channel (FCM, which relays to APNs on iOS). Tests use
/// a fake.
abstract class PushMessaging {
  /// Asks the user to allow notifications; true when allowed.
  Future<bool> requestPermission();

  /// This device's FCM token, or null when the platform has none yet.
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// Notifications the user tapped while the app was running.
  Stream<PushMessage> get taps;

  /// Notifications that arrived while the app was in front (the OS does
  /// not show these).
  Stream<PushMessage> get foreground;

  /// The notification that launched the app, if any.
  Future<PushMessage?> initialTap();
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._options);

  final FirebaseOptions _options;
  Future<FirebaseMessaging>? _ready;

  Future<FirebaseMessaging> _messaging() => _ready ??= () async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
    return FirebaseMessaging.instance;
  }();

  Stream<T> _after<T>(Stream<T> Function() stream) =>
      Stream.fromFuture(_messaging()).asyncExpand((_) => stream());

  static Iterable<PushMessage> _readAll(RemoteMessage message) => [
    ?_read(message),
  ];

  static PushMessage? _read(RemoteMessage message) => PushMessage.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );

  @override
  Future<bool> requestPermission() async {
    final settings = await (await _messaging()).requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    final messaging = await _messaging();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // getToken fails until APNs has handed the app its device token,
      // which can lag behind the permission prompt.
      for (var i = 0; i < 10; i++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return messaging.getToken();
  }

  @override
  Stream<String> get tokenRefresh =>
      _after(() => FirebaseMessaging.instance.onTokenRefresh);

  @override
  Stream<PushMessage> get taps =>
      _after(() => FirebaseMessaging.onMessageOpenedApp).expand(_readAll);

  @override
  Stream<PushMessage> get foreground =>
      _after(() => FirebaseMessaging.onMessage).expand(_readAll);

  @override
  Future<PushMessage?> initialTap() async {
    final message = await (await _messaging()).getInitialMessage();
    return message == null ? null : _read(message);
  }
}
