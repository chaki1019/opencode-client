import 'package:dio/dio.dart';

class RelayException implements Exception {
  const RelayException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the push relay (push/relay): registers this device's token
/// under a pairing key and can send a test notification through it.
class RelayClient {
  RelayClient(String baseUrl, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  Future<void> register({
    required String key,
    required String token,
    required String platform,
  }) => _send('POST', '/v1/devices', {
    'key': key,
    'token': token,
    'platform': platform,
  });

  Future<void> unregister({required String key, required String token}) =>
      _send('DELETE', '/v1/devices', {'key': key, 'token': token});

  /// Sends a notification as the plugin would, to check the whole path.
  Future<void> sendTest({required String key, required String title}) => _send(
    'POST',
    '/v1/notify',
    {'kind': 'completed', 'title': title, 'body': '', 'sessionID': ''},
    headers: {'Authorization': 'Bearer $key'},
  );

  Future<void> _send(
    String method,
    String path,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (e) {
      throw RelayException(e.message ?? e.type.name);
    }
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw RelayException('HTTP $status: ${response.data}');
    }
  }
}
