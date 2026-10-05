import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/remote_settings.dart';
import '../../core/update/update_checker.dart';
import '../config/remote_values.dart';

bool get _storePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// The relay's version check, for builds without Remote Config. Null when
/// this build has no relay, or on a platform without a store.
final updateCheckerProvider = Provider<UpdateChecker?>((ref) {
  if (!_storePlatform) return null;
  final url = updateCheckUrl();
  return url == null ? null : UpdateChecker(url);
});

/// The installed app's version and package name.
final packageInfoProvider = Provider<Future<PackageInfo>>(
  (ref) => PackageInfo.fromPlatform(),
);

/// The app's version and build number, as shown in settings.
final appVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  final info = await ref.watch(packageInfoProvider);
  return '${info.version} (${info.buildNumber})';
});

/// Reads the minimum versions from Remote Config when the build has it
/// (fetched at launch and on resume, and pushed on console changes);
/// otherwise asks the relay at launch and on resume, at most every
/// [recheckAfter]. Once an update is required the app stays blocked until
/// it is replaced by a newer build.
class RequiredUpdateNotifier extends Notifier<RequiredUpdate?> {
  static const recheckAfter = Duration(minutes: 30);

  DateTime? _lastCheck;
  bool _checking = false;
  bool _blocked = false;

  @override
  RequiredUpdate? build() {
    if (_storePlatform && ref.watch(remoteSettingsProvider).available) {
      ref.listen(
        remoteValuesProvider,
        (_, values) => _apply(remoteSettingsJson(values)),
        fireImmediately: true,
      );
      return null;
    }
    final checker = ref.watch(updateCheckerProvider);
    if (checker == null) return null;
    final listener = AppLifecycleListener(onResume: () => _check(checker));
    ref.onDispose(listener.dispose);
    _check(checker);
    return null;
  }

  Future<void> _check(UpdateChecker checker) async {
    if (_checking || _blocked) return;
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < recheckAfter) return;
    _checking = true;
    try {
      final info = await ref.read(packageInfoProvider);
      final required = await checker.check(
        installedVersion: info.version,
        platform: _platformName,
      );
      _lastCheck = DateTime.now();
      if (required != null) await _block(required);
    } catch (_) {
      // Fail open: an unreadable version or a broken plugin never blocks.
    } finally {
      _checking = false;
    }
  }

  Future<void> _apply(Map<String, Object?> json) async {
    if (_blocked) return;
    try {
      final info = await ref.read(packageInfoProvider);
      final required = UpdateChecker.requiredUpdate(
        json,
        installedVersion: info.version,
        platform: _platformName,
      );
      if (required != null) await _block(required);
    } catch (_) {
      // Fail open, as with the relay.
    }
  }

  static String get _platformName =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

  Future<void> _block(RequiredUpdate required) async {
    if (_blocked || !ref.mounted) return;
    final info = await ref.read(packageInfoProvider);
    if (_blocked || !ref.mounted) return;
    final android = defaultTargetPlatform == TargetPlatform.android;
    _blocked = true;
    state = RequiredUpdate(
      installed: required.installed,
      minimum: required.minimum,
      // Play's listing can be built from the package name; the App Store
      // needs the numeric id, so iOS relies on the server.
      storeUrl:
          required.storeUrl ??
          (android
              ? 'https://play.google.com/store/apps/details?id=${info.packageName}'
              : null),
    );
  }
}

final requiredUpdateProvider =
    NotifierProvider<RequiredUpdateNotifier, RequiredUpdate?>(
      RequiredUpdateNotifier.new,
    );
