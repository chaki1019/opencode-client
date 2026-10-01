import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_config.freezed.dart';
part 'server_config.g.dart';

/// A saved OpenCode server. The password is kept out of this object's JSON
/// and lives in secure storage, keyed by [id].
@freezed
abstract class ServerConfig with _$ServerConfig {
  const ServerConfig._();

  const factory ServerConfig({
    required String id,
    required String baseUrl,
    @Default('opencode') String username,
    String? label,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);

  String get displayName => (label?.isNotEmpty ?? false) ? label! : host;

  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;

  /// Normalizes user input like `192.168.1.5:4096` into `http://192.168.1.5:4096`.
  static String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return value;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
