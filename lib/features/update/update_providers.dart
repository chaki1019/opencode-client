import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/update/update_checker.dart';

/// Null when this build has no update server, or on a platform without a
/// store.
final updateCheckerProvider = Provider<UpdateChecker?>((ref) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    return null;
  }
  final url = updateCheckUrl();
  return url == null ? null : UpdateChecker(url);
});

/// The installed app's version and package name.
final packageInfoProvider = Provider<Future<PackageInfo>>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Checks at launch and again when the app comes back to the foreground,
/// at most every [recheckAfter]. Once an update is required the app stays
/// blocked until it is replaced by a newer build.
class RequiredUpdateNotifier extends Notifier<RequiredUpdate?> {
  static const recheckAfter = Duration(minutes: 30);

  DateTime? _lastCheck;
  bool _checking = false;
  bool _blocked = false;

  @override
  RequiredUpdate? build() {
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
      final android = defaultTargetPlatform == TargetPlatform.android;
      final required = await checker.check(
        installedVersion: info.version,
        platform: android ? 'android' : 'ios',
      );
      _lastCheck = DateTime.now();
      if (required == null || !ref.mounted) return;
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
    } catch (_) {
      // Fail open: an unreadable version or a broken plugin never blocks.
    } finally {
      _checking = false;
    }
  }
}

final requiredUpdateProvider =
    NotifierProvider<RequiredUpdateNotifier, RequiredUpdate?>(
      RequiredUpdateNotifier.new,
    );
