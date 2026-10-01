import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/project.dart';
import 'api_errors.dart';

class ProjectBootstrap {
  const ProjectBootstrap({required this.projects, this.current});

  final List<Project> projects;
  final Project? current;
}

/// HTTP transport to one OpenCode server's v2 HttpAPI (`/api/...`),
/// authenticated with Basic auth.
///
/// Requests may be scoped to a project directory; we send both the
/// `directory` query parameter and the `x-opencode-directory` header.
class OpenCodeClient {
  OpenCodeClient({
    required String baseUrl,
    required String username,
    required String password,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..responseType = ResponseType.plain
      // Status codes are interpreted per call (the probe treats 404 as a
      // signal, not an error).
      ..validateStatus = (_) => true;
    if (password.isNotEmpty) {
      final token = base64Encode(utf8.encode('$username:$password'));
      _dio.options.headers['Authorization'] = 'Basic $token';
    }
  }

  final Dio _dio;

  /// Verifies the server is healthy and speaks the v2 API.
  ///
  /// `/api/health` must return `{healthy: true, version, pid}`. When it is
  /// missing (404/405 or the web app's HTML), `/api/info` is tried. A server
  /// with neither, or with the old minimal `{"healthy":true}` body, is an
  /// older OpenCode and raises [UnsupportedServerException].
  Future<ServerHealth> connect() async {
    final health = await _request('/api/health');
    if (health.statusCode == 404 ||
        health.statusCode == 405 ||
        _isHtml(health)) {
      return _probeInfo();
    }
    _ensureSuccess(health);
    final body = _decode(health);
    if (body is! Map) throw const OpenCodeApiException('Invalid health body');
    if (body['healthy'] == true &&
        body['version'] == null &&
        body['pid'] == null) {
      throw const UnsupportedServerException();
    }
    final version = body['version'];
    final pid = body['pid'];
    if (body['healthy'] != true ||
        version is! String ||
        pid is! int ||
        pid < 0) {
      throw const OpenCodeApiException('Invalid health body');
    }
    return ServerHealth(version: version, pid: pid);
  }

  Future<ServerHealth> _probeInfo() async {
    final info = await _request('/api/info');
    if (info.statusCode == 404 || info.statusCode == 405 || _isHtml(info)) {
      throw const UnsupportedServerException();
    }
    _ensureSuccess(info);
    final body = _decode(info);
    if (body is! Map) throw const OpenCodeApiException('Invalid info body');
    final version = body['version'];
    final pid = body['pid'];
    if (version is! String || version.isEmpty || pid is! int || pid < 0) {
      throw const OpenCodeApiException('Invalid info body');
    }
    return ServerHealth(version: version, pid: pid);
  }

  Future<ProjectBootstrap> loadProjects() async {
    // Resolve location first: it can register the current project.
    final location = _map(await _getJson('/api/location'));
    final locationProject = _map(location['project']);
    final listed = await _getJson('/api/project') as List;
    final projects = [for (final p in listed) Project.fromJson(_map(p))];
    final currentId = locationProject['id'] as String?;
    if (currentId != null && !projects.any((p) => p.id == currentId)) {
      projects.add(
        Project(
          id: currentId,
          directory: locationProject['directory'] as String? ?? '',
        ),
      );
    }
    return ProjectBootstrap(
      projects: projects,
      current: projects.where((p) => p.id == currentId).firstOrNull,
    );
  }

  Future<Object?> _getJson(String path, {String? directory}) async {
    final response = await _request(path, directory: directory);
    _ensureSuccess(response);
    return _decode(response);
  }

  Future<Response<String>> _request(
    String path, {
    String method = 'GET',
    String? directory,
    Object? body,
  }) async {
    try {
      return await _dio.request<String>(
        path,
        data: body == null ? null : jsonEncode(body),
        queryParameters: directory == null ? null : {'directory': directory},
        options: Options(
          method: method,
          headers: {
            'x-opencode-directory': ?directory,
            if (body != null) 'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      throw OpenCodeApiException(e.message ?? e.type.name);
    }
  }

  void _ensureSuccess(Response<String> response) {
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw OpenCodeApiException(response.data ?? '', statusCode: code);
    }
  }

  bool _isHtml(Response<String> response) {
    final contentType = response.headers.value('content-type') ?? '';
    final body = (response.data ?? '').trimLeft().toLowerCase();
    return contentType.contains('text/html') ||
        body.startsWith('<!doctype html') ||
        body.startsWith('<html');
  }

  Object? _decode(Response<String> response) {
    try {
      return jsonDecode(response.data ?? '');
    } on FormatException {
      throw const OpenCodeApiException('Response was not JSON');
    }
  }

  static Map<String, dynamic> _map(Object? value) =>
      (value as Map).cast<String, dynamic>();
}
