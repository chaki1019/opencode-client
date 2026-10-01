import 'dart:convert';

import 'package:dio/dio.dart';
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

  group('listSessions', () {
    Map<String, Object> session(String id) => {
      'id': id,
      'projectID': 'p1',
      'title': 'Session $id',
      'location': {'directory': '/srv/p1'},
      'time': {'created': 1, 'updated': 2},
    };

    test('sends the root-session filter on the first page', () async {
      final adapter = FakeAdapter({
        '/api/session': FakeRoute.json({
          'data': [session('a')],
          'cursor': {'next': 'c1'},
        }),
      });
      final page = await clientFor(adapter).listSessions(directory: '/srv/p1');
      expect(page.items.single.displayTitle, 'Session a');
      // A short page ends the list even if the server sent a cursor.
      expect(page.hasMore, isFalse);
      expect(adapter.requests.single.queryParameters, {
        'directory': '/srv/p1',
        'parentID': 'null',
        'order': 'desc',
        'limit': 50,
      });
    });

    test(
      'a full page keeps its cursor only if the lookahead finds more',
      () async {
        final adapter = FakeAdapter({
          '/api/session': (RequestOptions request) {
            final cursor = request.queryParameters['cursor'];
            if (cursor == null) {
              return FakeRoute.json({
                'data': [session('a'), session('b')],
                'cursor': {'next': 'c1'},
              });
            }
            return FakeRoute.json({
              'data': cursor == 'c1' ? [session('c')] : [],
            });
          },
        });
        final client = clientFor(adapter);
        final first = await client.listSessions(directory: '/d', limit: 2);
        expect(first.nextCursor, 'c1');
        expect(adapter.requests.last.queryParameters, {
          'cursor': 'c1',
          'limit': 1,
        });
      },
    );

    test('a full page with an empty lookahead ends the list', () async {
      final adapter = FakeAdapter({
        '/api/session': (RequestOptions request) =>
            request.queryParameters['cursor'] == null
            ? FakeRoute.json({
                'data': [session('a')],
                'cursor': {'next': 'c1'},
              })
            : FakeRoute.json({'data': []}),
      });
      final page = await clientFor(adapter)
          .listSessions(directory: '/d', limit: 1);
      expect(page.hasMore, isFalse);
    });
  });

  group('listMessages', () {
    test('returns entries oldest first and skips unknown types', () async {
      final adapter = FakeAdapter({
        '/api/session/s1/message': FakeRoute.json({
          'data': [
            {
              'id': 'a1',
              'type': 'assistant',
              'content': [
                {'type': 'text', 'text': 'hi'},
              ],
            },
            {'id': 'x', 'type': 'step-marker'},
            {'id': 'u1', 'type': 'user', 'text': 'hello'},
          ],
        }),
      });
      final page = await clientFor(adapter).listMessages(sessionId: 's1');
      expect(page.items.map((e) => e.id), ['u1', 'a1']);
      expect(adapter.requests.single.queryParameters, {
        'order': 'desc',
        'limit': 100,
      });
    });

    test('rejects a record without a type', () async {
      final adapter = FakeAdapter({
        '/api/session/s1/message': FakeRoute.json({
          'data': [
            {'id': 'u1'},
          ],
        }),
      });
      await expectLater(
        clientFor(adapter).listMessages(sessionId: 's1'),
        throwsA(isA<OpenCodeApiException>()),
      );
    });
  });
}
