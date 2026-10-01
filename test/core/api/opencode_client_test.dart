import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/api_errors.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';

import '../../support/fake_adapter.dart';

OpenCodeClient clientFor(FakeAdapter adapter, {String password = 'secret'}) =>
    OpenCodeClient(
      baseUrl: 'http://example.test',
      username: 'opencode',
      password: password,
      dio: fakeDio(adapter),
    );

final _healthy = FakeRoute.json({
  'healthy': true,
  'version': '2.0.1',
  'pid': 42,
});

void main() {
  group('connect', () {
    test('accepts a full v2 health body', () async {
      final health = await clientFor(FakeAdapter({'/api/health': _healthy}))
          .connect();
      expect(health.version, '2.0.1');
      expect(health.pid, 42);
    });

    test('uses /api/info when /api/health is missing', () async {
      final adapter = FakeAdapter({
        '/api/info': FakeRoute.json({'version': '2.1.0', 'pid': 7}),
      });
      expect((await clientFor(adapter).connect()).version, '2.1.0');
    });

    test('rejects a server without the v2 API', () async {
      final adapter = FakeAdapter({
        '/global/health': FakeRoute.json({'healthy': true}),
      });
      await expectLater(
        clientFor(adapter).connect(),
        throwsA(isA<UnsupportedServerException>()),
      );
      expect(adapter.requests.map((r) => r.path), ['/api/health', '/api/info']);
    });

    test('rejects the old minimal health body', () async {
      final adapter = FakeAdapter({
        '/api/health': FakeRoute.json({'healthy': true}),
      });
      await expectLater(
        clientFor(adapter).connect(),
        throwsA(isA<UnsupportedServerException>()),
      );
    });

    test('rejects a server that serves the web app HTML for /api', () async {
      final adapter = FakeAdapter({
        '/api/health': const FakeRoute(
          200,
          '<!DOCTYPE html><html></html>',
          contentType: 'text/html',
        ),
        '/api/info': const FakeRoute(
          200,
          '<html></html>',
          contentType: 'text/html',
        ),
      });
      await expectLater(
        clientFor(adapter).connect(),
        throwsA(isA<UnsupportedServerException>()),
      );
    });

    test('reports 401 as unauthorized', () async {
      final adapter = FakeAdapter({
        '/api/health': const FakeRoute(
          401,
          'Unauthorized',
          contentType: 'text/plain',
        ),
      });
      await expectLater(
        clientFor(adapter).connect(),
        throwsA(
          isA<OpenCodeApiException>().having(
            (e) => e.isUnauthorized,
            'isUnauthorized',
            true,
          ),
        ),
      );
    });

    test('rejects a malformed health body', () async {
      final adapter = FakeAdapter({
        '/api/health': FakeRoute.json({
          'healthy': true,
          'version': '2.0.0',
          'pid': -1,
        }),
      });
      await expectLater(
        clientFor(adapter).connect(),
        throwsA(
          isA<OpenCodeApiException>().having(
            (e) => e is UnsupportedServerException,
            'unsupported',
            false,
          ),
        ),
      );
    });

    test('sends Basic auth', () async {
      final adapter = FakeAdapter({'/api/health': _healthy});
      await clientFor(adapter).connect();
      expect(
        adapter.requests.single.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('opencode:secret'))}',
      );
    });

    test('omits auth when no password is set', () async {
      final adapter = FakeAdapter({'/api/health': _healthy});
      await clientFor(adapter, password: '').connect();
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('loadProjects', () {
    test('maps canonical to directory and adds the located project', () async {
      final adapter = FakeAdapter({
        '/api/location': FakeRoute.json({
          'directory': '/srv/new',
          'project': {'id': 'new', 'directory': '/srv/new'},
        }),
        '/api/project': FakeRoute.json([
          {
            'id': 'p1',
            'canonical': '/srv/p1',
            'vcs': 'git',
            'sandboxes': ['/srv/p1-wt'],
            'icon': {'override': 'x', 'color': 'blue'},
            'time': {'created': 1, 'updated': 2},
          },
        ]),
      });
      final result = await clientFor(adapter).loadProjects();
      expect(result.projects.map((p) => p.directory), ['/srv/p1', '/srv/new']);
      expect(result.projects.first.sandboxes, ['/srv/p1-wt']);
      expect(result.projects.first.icon?.overrideUrl, 'x');
      expect(result.projects.first.displayName, 'p1');
      expect(result.current?.id, 'new');
    });
  });
}
