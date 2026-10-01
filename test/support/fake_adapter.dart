import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeRoute {
  const FakeRoute(
    this.status,
    this.body, {
    this.contentType = 'application/json',
  });

  final int status;
  final String body;
  final String contentType;

  factory FakeRoute.json(Object body, {int status = 200}) =>
      FakeRoute(status, jsonEncode(body));
}

/// Serves canned responses keyed by path and records every request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, FakeRoute> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route =
        routes[options.path] ??
        const FakeRoute(404, 'Not Found', contentType: 'text/plain');
    return ResponseBody.fromString(
      route.body,
      route.status,
      headers: {
        Headers.contentTypeHeader: [route.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;
