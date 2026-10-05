import 'package:dio/dio.dart';

import 'app_version.dart';

/// Where the minimum app versions are served. `UPDATE_CHECK_URL` wins;
/// otherwise the push relay's `/v1/app-version` is used. Null when the
/// build has neither, which turns the check off.
String? updateCheckUrl({
  String override = const String.fromEnvironment('UPDATE_CHECK_URL'),
  String relayUrl = const String.fromEnvironment('PUSH_RELAY_URL'),
}) {
  if (override.isNotEmpty) return override;
  if (relayUrl.isEmpty) return null;
  final base = relayUrl.endsWith('/')
      ? relayUrl.substring(0, relayUrl.length - 1)
      : relayUrl;
  return '$base/v1/app-version';
}

/// An installed version below the server's minimum.
class RequiredUpdate {
  const RequiredUpdate({
    required this.installed,
    required this.minimum,
    this.storeUrl,
  });

  final AppVersion installed;
  final AppVersion minimum;
  final String? storeUrl;
}

/// Asks the update server whether this version may still run. Every
/// failure (offline, timeout, bad response) lets the app run, so an outage
/// never locks users out.
class UpdateChecker {
  UpdateChecker(this.url, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 5)
      ..receiveTimeout = const Duration(seconds: 5);
  }

  final String url;
  final Dio _dio;

  /// The server's response, or null when it could not be read. The same
  /// response carries the ad switches (`ads`).
  Future<Object?> fetch() async {
    try {
      return (await _dio.get<Object?>(url)).data;
    } on DioException {
      return null;
    }
  }

  Future<RequiredUpdate?> check({
    required String installedVersion,
    required String platform,
  }) async => requiredUpdate(
    await fetch(),
    installedVersion: installedVersion,
    platform: platform,
  );

  /// The update [response] asks of [installedVersion], if any.
  static RequiredUpdate? requiredUpdate(
    Object? response, {
    required String installedVersion,
    required String platform,
  }) {
    final installed = AppVersion.tryParse(installedVersion);
    if (installed == null) return null;
    final policy = UpdatePolicy.fromJson(response, platform);
    if (!policy.requiresUpdate(installed)) return null;
    return RequiredUpdate(
      installed: installed,
      minimum: policy.minimum!,
      storeUrl: policy.storeUrl,
    );
  }
}
