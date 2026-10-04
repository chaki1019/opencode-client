import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/app_localizations.dart';
import '../storage/server_store.dart';
import 'push_config.dart';
import 'push_crypto.dart';
import 'push_inbox.dart';
import 'push_message.dart';
import 'push_store.dart';

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

  /// Lets the iOS Notification Service Extension decrypt notifications for
  /// [keys]; a no-op elsewhere.
  Future<void> shareKeys(PushKeys keys);

  Future<void> unshareKeys(String keyId);
}

const _channelId = 'agent_events';

/// Android shows relay messages itself: they arrive as data only, so the
/// relay never has readable text to put in a notification.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage remote) async {
  final message = PushMessage.fromData(remote.data);
  if (message == null) return;
  await showPushNotification(message);
}

/// Decrypts [message] and posts it as a local notification (Android).
Future<void> showPushNotification(PushMessage message) async {
  final resolved = await resolvePush(
    message,
    servers: await ServerStore().loadServers(),
    store: PushStore(),
  );
  // Not one of ours (a removed server, or a stale registration).
  if (resolved == null) return;
  final l10n = lookupAppLocalizations(_deviceLocale());
  final text = pushText(l10n, message.kind, resolved.content);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: _initSettings);
  await plugin.show(
    id: message.sessionId.hashCode,
    title: text.title,
    body: text.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.pushChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(message.toData()),
  );
}

const _initSettings = InitializationSettings(
  android: AndroidInitializationSettings('@drawable/ic_notification'),
);

Locale _deviceLocale() {
  final locale = PlatformDispatcher.instance.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      )
      ? Locale(locale.languageCode)
      : const Locale('en');
}

PushMessage? _fromPayload(String? payload) {
  if (payload == null) return null;
  try {
    final data = jsonDecode(payload);
    return data is Map<String, dynamic> ? PushMessage.fromData(data) : null;
  } on FormatException {
    return null;
  }
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._options);

  final FirebaseOptions _options;
  Future<FirebaseMessaging>? _ready;
  final _localTaps = StreamController<PushMessage>.broadcast();
  FlutterLocalNotificationsPlugin? _local;

  static const _keys = MethodChannel('opencode/push_keys');

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Future<FirebaseMessaging> _messaging() => _ready ??= () async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
    if (_android) {
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      final local = FlutterLocalNotificationsPlugin();
      await local.initialize(
        settings: _initSettings,
        onDidReceiveNotificationResponse: (response) {
          final message = _fromPayload(response.payload);
          if (message != null) _localTaps.add(message);
        },
      );
      _local = local;
    }
    return FirebaseMessaging.instance;
  }();

  Stream<T> _after<T>(Stream<T> Function() stream) =>
      Stream.fromFuture(_messaging()).asyncExpand((_) => stream());

  static Iterable<PushMessage> _readAll(RemoteMessage message) => [
    ?PushMessage.fromData(message.data),
  ];

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

  /// iOS taps come from FCM; Android taps come from the local notification
  /// the background handler posted.
  @override
  Stream<PushMessage> get taps => _after(
    () => _android
        ? _localTaps.stream
        : FirebaseMessaging.onMessageOpenedApp.expand(_readAll),
  );

  @override
  Stream<PushMessage> get foreground =>
      _after(() => FirebaseMessaging.onMessage).expand(_readAll);

  @override
  Future<PushMessage?> initialTap() async {
    final messaging = await _messaging();
    if (_android) {
      final launch = await _local?.getNotificationAppLaunchDetails();
      if (launch == null || !launch.didNotificationLaunchApp) return null;
      return _fromPayload(launch.notificationResponse?.payload);
    }
    final message = await messaging.getInitialMessage();
    return message == null ? null : _readAll(message).firstOrNull;
  }

  @override
  Future<void> shareKeys(PushKeys keys) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _keys.invokeMethod<void>('set', {
      'keyId': keys.keyId,
      'key': base64.encode(keys.encKey),
    });
  }

  @override
  Future<void> unshareKeys(String keyId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _keys.invokeMethod<void>('remove', {'keyId': keyId});
  }
}

/// Builds the real channel from the build's settings, or null when push is
/// off in this build.
PushMessaging? pushMessagingFor(PushConfig config) {
  final options = config.firebaseOptions;
  if (!config.isConfigured || options == null) return null;
  return FirebasePushMessaging(options);
}
