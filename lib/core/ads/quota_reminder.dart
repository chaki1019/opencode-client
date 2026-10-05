import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// A local notification at midnight saying the day's messages are back.
/// Builds without a notification platform use [QuotaReminder.none].
abstract class QuotaReminder {
  const factory QuotaReminder.none() = _NoQuotaReminder;

  /// Replaces any reminder already set.
  Future<void> remindAt(
    DateTime when, {
    required String title,
    required String body,
    required String channelName,
  });

  Future<void> cancel();

  /// Asks for permission to notify; true when granted.
  Future<bool> requestPermission();
}

class _NoQuotaReminder implements QuotaReminder {
  const _NoQuotaReminder();

  @override
  Future<void> remindAt(
    DateTime when, {
    required String title,
    required String body,
    required String channelName,
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> requestPermission() async => false;
}

class LocalQuotaReminder implements QuotaReminder {
  static const _id = 7001;
  static const _channelId = 'message_quota';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// iOS needs the plugin started; Android does not, and starting it again
  /// there would replace the push notifications' tap handler.
  Future<void> _start() => _ready ??= _ios
      ? _plugin.initialize(
          settings: const InitializationSettings(
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        )
      : Future.value();

  @override
  Future<void> remindAt(
    DateTime when, {
    required String title,
    required String body,
    required String channelName,
  }) async {
    try {
      await _start();
      await _plugin.zonedSchedule(
        id: _id,
        // An instant in UTC, so no time zone database is needed.
        scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channelName,
            icon: 'ic_notification',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // A few minutes late is fine, and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('Quota reminder failed: $error');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _start();
      await _plugin.cancel(id: _id);
    } catch (error) {
      debugPrint('Quota reminder cancel failed: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _start();
      final granted = _ios
          ? await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true)
          : await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }
}
