import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/project.dart';
import '../models/session.dart';
import '../models/timeline.dart';
import 'api_errors.dart';

class ProjectBootstrap {
  const ProjectBootstrap({required this.projects, this.current});

  final List<Project> projects;
  final Project? current;
}

/// One page of a cursor-paginated list. [nextCursor] is null on the last
/// page.
class Page<T> {
  const Page(this.items, this.nextCursor);

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
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

  /// Root sessions of a project directory, newest first.
  Future<Page<Session>> listSessions({
    required String directory,
    String? cursor,
    int limit = 50,
  }) async {
    final page = await _getPage(
      '/api/session',
      cursor == null
          ? {
              'directory': directory,
              'parentID': 'null',
              'order': 'desc',
              'limit': limit,
            }
          : {'cursor': cursor, 'limit': limit},
      cursor: cursor,
      limit: limit,
    );
    return Page([
      for (final item in page.items) Session.fromJson(_map(item)),
    ], page.nextCursor);
  }

  /// A page of a session's timeline. The first page holds the newest
  /// [limit] records; [Page.nextCursor] continues to older ones. Entries are
  /// returned oldest first.
  Future<Page<TimelineEntry>> listMessages({
    required String sessionId,
    String? cursor,
    int limit = 100,
  }) async {
    assert(limit > 0 && limit <= 200);
    final page = await _getPage(
      '/api/session/${Uri.encodeComponent(sessionId)}/message',
      cursor == null
          ? {'order': 'desc', 'limit': limit}
          : {'cursor': cursor, 'limit': limit},
      cursor: cursor,
      limit: limit,
    );
    final entries = <TimelineEntry>[];
    for (final item in page.items.reversed) {
      try {
        final entry = TimelineEntry.tryParse(_map(item));
        if (entry != null) entries.add(entry);
      } on FormatException catch (e) {
        throw OpenCodeApiException('Invalid timeline record: ${e.message}');
      }
    }
    return Page(entries, page.nextCursor);
  }

  /// IDs of sessions that are currently running (status other than idle).
  Future<Set<String>> activeSessionIds() async {
    final body = _map(await _getJson('/api/session/active'));
    final data = _obj(body['data']) ?? const {};
    return {
      for (final MapEntry(:key, :value) in data.entries)
        if (_obj(value)?['type'] != 'idle') key,
    };
  }

  /// Opens the server's v2 event stream (`GET /api/event`) and returns the
  /// raw SSE bytes. The request has no receive timeout; callers detect a
  /// stalled stream themselves. Cancel with [cancelToken].
  Future<Stream<List<int>>> openEventStream({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<ResponseBody>(
        '/api/event',
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: {
            'Accept': 'text/event-stream',
            'Accept-Encoding': 'identity',
            'Cache-Control': 'no-cache',
          },
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw OpenCodeApiException('Event stream refused', statusCode: code);
      }
      return response.data!.stream;
    } on DioException catch (e) {
      throw OpenCodeApiException(e.message ?? e.type.name);
    }
  }

  /// Fetches `{data: [...], cursor: {next}}` pages.
  ///
  /// The server can return a `next` cursor even on the last page, so a short
  /// page ends the list and a full page is confirmed with a one-item
  /// lookahead that is not consumed. If the lookahead fails, the cursor is
  /// kept so the user can still try to load more.
  Future<Page<Object?>> _getPage(
    String path,
    Map<String, Object> query, {
    required String? cursor,
    required int limit,
  }) async {
    final body = _map(await _getJson(path, query: query));
    final items = body['data'] as List? ?? const [];
    var next = _obj(body['cursor'])?['next'] as String?;
    if (items.length < limit || next == cursor) next = null;
    if (next != null) {
      try {
        final probe = _map(
          await _getJson(path, query: {'cursor': next, 'limit': 1}),
        );
        if ((probe['data'] as List? ?? const []).isEmpty) next = null;
      } on OpenCodeApiException {
        // Keep the continuation.
      }
    }
    return Page(items, next);
  }

  Future<Object?> _getJson(
    String path, {
    String? directory,
    Map<String, Object>? query,
  }) async {
    final response = await _request(path, directory: directory, query: query);
    _ensureSuccess(response);
    return _decode(response);
  }

  Future<Response<String>> _request(
    String path, {
    String method = 'GET',
    String? directory,
    Map<String, Object>? query,
    Object? body,
  }) async {
    try {
      return await _dio.request<String>(
        path,
        data: body == null ? null : jsonEncode(body),
        queryParameters: {'directory': ?directory, ...?query},
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

  static Map<String, dynamic>? _obj(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;
}
