import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/api_errors.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';

import 'dart:typed_data';

import 'package:opencode_mobile/core/models/attachment.dart';
import 'package:opencode_mobile/core/models/form.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/core/models/prompts.dart';
import 'package:opencode_mobile/core/models/session.dart';

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

  test('serverDirectory reads the location directory', () async {
    final adapter = FakeAdapter({
      '/api/location': FakeRoute.json({
        'directory': '/home/me',
        'project': {'id': 'global', 'directory': '/'},
      }),
    });
    expect(await clientFor(adapter).serverDirectory(), '/home/me');
  });

  group('openProject', () {
    test('resolves the folder and returns the listed project', () async {
      final adapter = FakeAdapter({
        '/api/fs/list': FakeRoute.json({'data': []}),
        '/api/location': FakeRoute.json({
          'directory': '/srv/app/sub',
          'project': {'id': 'app', 'directory': '/srv/app'},
        }),
        '/api/project': FakeRoute.json([
          {'id': 'app', 'canonical': '/srv/app', 'name': 'App'},
        ]),
      });
      final project = await clientFor(adapter).openProject('/srv/app/sub');
      expect(project.id, 'app');
      expect(project.displayName, 'App');
      final location = adapter.requests.firstWhere(
        (r) => r.path == '/api/location',
      );
      expect(location.queryParameters['location[directory]'], '/srv/app/sub');
      expect(location.headers['x-opencode-directory'], '/srv/app/sub');
    });

    test('keeps a non-Git folder as its own directory', () async {
      final adapter = FakeAdapter({
        '/api/fs/list': FakeRoute.json({'data': []}),
        '/api/location': FakeRoute.json({
          'directory': '/srv/notes',
          'project': {'id': 'global', 'directory': '/'},
        }),
      });
      final project = await clientFor(adapter).openProject('/srv/notes');
      expect(project.id, 'global');
      expect(project.directory, '/srv/notes');
    });

    test('fails without resolving when the folder cannot be read', () async {
      final adapter = FakeAdapter({
        '/api/fs/list': FakeRoute.json({'message': 'nope'}, status: 400),
      });
      await expectLater(
        clientFor(adapter).openProject('/missing'),
        throwsA(isA<OpenCodeApiException>()),
      );
      expect(adapter.requests.map((r) => r.path), ['/api/fs/list']);
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

  group('sendPrompt', () {
    FakeAdapter promptServer(
      FakeRoute Function(Map<String, dynamic> body) reply,
    ) => FakeAdapter({
      '/api/session/s1/prompt': (RequestOptions request) =>
          reply(jsonDecode(request.data as String) as Map<String, dynamic>),
    });

    test('accepts when the receipt echoes our ID', () async {
      late Map<String, dynamic> sent;
      final adapter = promptServer((body) {
        sent = body;
        return FakeRoute.json({
          'data': {
            'id': body['id'],
            'sessionID': 's1',
            'delivery': 'immediate',
          },
        });
      });
      final result = await clientFor(adapter)
          .sendPrompt(sessionId: 's1', messageId: 'msg_1', text: 'hi');
      expect(result, PromptAdmission.accepted);
      expect(sent, {'id': 'msg_1', 'text': 'hi', 'resume': true});
      expect(adapter.requests.single.method, 'POST');
    });

    test('a 4xx is a rejection, but 409 and 5xx are uncertain', () async {
      Future<PromptAdmission> withStatus(int status) =>
          clientFor(promptServer((_) => FakeRoute(status, '{}')))
              .sendPrompt(sessionId: 's1', messageId: 'm', text: 't');
      expect(await withStatus(400), PromptAdmission.rejected);
      expect(await withStatus(409), PromptAdmission.uncertain);
      expect(await withStatus(503), PromptAdmission.uncertain);
    });

    test('a receipt for another ID is uncertain', () async {
      final adapter = promptServer(
        (_) => FakeRoute.json({
          'data': {'id': 'other', 'sessionID': 's1'},
        }),
      );
      expect(
        await clientFor(adapter)
            .sendPrompt(sessionId: 's1', messageId: 'm', text: 't'),
        PromptAdmission.uncertain,
      );
    });
  });

  group('session operations', () {
    test('createSession sends the location and returns the session', () async {
      late Map<String, dynamic> sent;
      final adapter = FakeAdapter({
        '/api/session': (RequestOptions request) {
          sent = jsonDecode(request.data as String) as Map<String, dynamic>;
          return FakeRoute.json({
            'data': {
              'id': 'new',
              'projectID': 'p',
              'location': {'directory': '/srv/app'},
              'time': {'created': 1, 'updated': 1},
            },
          });
        },
      });
      final session = await clientFor(adapter)
          .createSession(directory: '/srv/app');
      expect(session.id, 'new');
      expect(sent, {
        'location': {'directory': '/srv/app'},
      });
    });

    test('selectModel and interrupt post to the session', () async {
      final adapter = FakeAdapter({
        '/api/session/s1/model': const FakeRoute(204, ''),
        '/api/session/s1/interrupt': const FakeRoute(204, ''),
      });
      final client = clientFor(adapter);
      await client.selectModel(
        's1',
        const ModelRef(providerID: 'anthropic', id: 'claude', variant: 'high'),
      );
      await client.interrupt('s1');
      expect(jsonDecode(adapter.requests.first.data as String), {
        'model': {'providerID': 'anthropic', 'id': 'claude', 'variant': 'high'},
      });
      expect(adapter.requests.map((r) => r.path), [
        '/api/session/s1/model',
        '/api/session/s1/interrupt',
      ]);
    });
  });

  group('catalog', () {
    test('listModels keeps enabled models of available providers', () async {
      final adapter = FakeAdapter({
        '/api/provider': FakeRoute.json({
          'data': [
            {'id': 'a', 'name': 'Provider A'},
            {'id': 'b', 'name': 'Provider B', 'activation': 'disabled'},
          ],
        }),
        '/api/model': FakeRoute.json({
          'data': [
            {
              'id': 'm1',
              'providerID': 'a',
              'name': 'Model 1',
              'enabled': true,
              'variants': [
                {'id': 'low'},
                {'id': 'high'},
              ],
            },
            {'id': 'm2', 'providerID': 'a', 'name': 'Off', 'enabled': false},
            {'id': 'm3', 'providerID': 'b', 'name': 'B', 'enabled': true},
          ],
        }),
      });
      final models = await clientFor(adapter).listModels(directory: '/d');
      expect(models.map((m) => m.id), ['m1']);
      expect(models.single.providerName, 'Provider A');
      expect(models.single.variants, ['low', 'high']);
      expect(adapter.requests.first.queryParameters, {
        'location[directory]': '/d',
      });
    });

    test('listAgents parses agents and marks subagents unselectable', () async {
      final adapter = FakeAdapter({
        '/api/agent': FakeRoute.json({
          'data': [
            {'id': 'build', 'mode': 'primary', 'hidden': false},
            {'id': 'explore', 'mode': 'subagent', 'hidden': false},
          ],
        }),
      });
      final agents = await clientFor(adapter).listAgents(directory: '/d');
      expect(agents.map((a) => a.isSelectable), [true, false]);
    });
  });

  group('permissions and forms', () {
    test('lists permissions and replies with a decision', () async {
      late RequestOptions replied;
      final adapter = FakeAdapter({
        '/api/session/ses_1/permission': FakeRoute.json({
          'data': [
            {
              'id': 'per_1',
              'sessionID': 'ses_1',
              'action': 'bash',
              'resources': ['git status*'],
            },
            {'broken': true},
          ],
        }),
        '/api/session/ses_1/permission/per_1/reply': (RequestOptions request) {
          replied = request;
          return const FakeRoute(204, '');
        },
      });
      final client = clientFor(adapter);
      final requests = await client.listPermissions('ses_1');
      expect(requests.single.id, 'per_1');

      await client.replyPermission(requests.single, PermissionDecision.always);
      expect(replied.method, 'POST');
      expect(jsonDecode(replied.data as String), {'decision': 'always'});
    });

    test('lists, answers and cancels forms within the location', () async {
      final requests = <RequestOptions>[];
      FakeRoute record(RequestOptions request) {
        requests.add(request);
        return const FakeRoute(204, '');
      }

      final adapter = FakeAdapter({
        '/api/session/ses_1/form': FakeRoute.json({
          'location': {'directory': '/tmp/project'},
          'data': [
            {
              'id': 'frm_1',
              'sessionID': 'ses_1',
              'title': 'Confirm',
              'fields': [
                {
                  'key': 'proceed',
                  'type': 'string',
                  'required': true,
                  'options': [
                    {'value': 'yes', 'label': 'Yes'},
                  ],
                },
              ],
            },
          ],
        }),
        '/api/session/ses_1/form/frm_1/reply': record,
        '/api/session/ses_1/form/frm_1': record,
      });
      final client = clientFor(adapter);
      final forms = await client.listForms('ses_1', directory: '/tmp/project');
      final form = forms.single;
      expect(form.title, 'Confirm');
      expect(
        adapter.requests.first.queryParameters['location[directory]'],
        '/tmp/project',
      );

      await client.replyForm(
        form,
        directory: '/tmp/project',
        answer: {'proceed': 'yes'},
      );
      await client.cancelForm(form, directory: '/tmp/project');
      expect(requests.first.method, 'POST');
      expect(jsonDecode(requests.first.data as String), {
        'answer': {'proceed': 'yes'},
      });
      expect(requests.last.method, 'DELETE');
      expect(requests.last.data, isNull);
      expect(
        requests.last.queryParameters['location[directory]'],
        '/tmp/project',
      );
    });

    test('exposes the server message of a form error', () async {
      final adapter = FakeAdapter({
        '/api/session/s/form/f/reply': FakeRoute.json({
          '_tag': 'FormInvalidAnswerError',
          'message': 'proceed is required',
        }, status: 400),
      });
      const form = FormRequest(id: 'f', sessionId: 's', title: '', fields: []);
      await expectLater(
        clientFor(adapter).replyForm(form, directory: '/d', answer: {}),
        throwsA(
          isA<OpenCodeApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.detail, 'detail', 'proceed is required'),
        ),
      );
    });
  });

  group('project tools', () {
    const session = {
      'id': 'ses_1',
      'projectID': 'p',
      'title': 'Renamed',
      'location': {'directory': '/repo'},
      'time': {'created': 1, 'updated': 2},
    };

    test('renames, forks, compacts and deletes a session', () async {
      final requests = <RequestOptions>[];
      final adapter = FakeAdapter({
        '/api/session/ses_1': (RequestOptions request) {
          requests.add(request);
          return request.method == 'GET'
              ? FakeRoute.json({'data': session})
              : const FakeRoute(204, '');
        },
        '/api/session/ses_1/fork': (RequestOptions request) {
          requests.add(request);
          return FakeRoute.json({
            'data': {...session, 'id': 'ses_fork'},
          });
        },
        '/api/session/ses_1/compact': (RequestOptions request) {
          requests.add(request);
          final body = jsonDecode(request.data as String) as Map;
          return FakeRoute.json({
            'data': {'id': body['id'], 'sessionID': 'ses_1'},
          });
        },
      });
      final client = clientFor(adapter);

      final renamed = await client.renameSession('ses_1', 'Renamed');
      expect(renamed.title, 'Renamed');
      expect(requests[0].method, 'PATCH');
      expect(jsonDecode(requests[0].data as String), {'title': 'Renamed'});
      expect(requests[1].method, 'GET');

      final fork = await client.forkSession('ses_1', beforeMessageId: 'msg_1');
      expect(fork.id, 'ses_fork');
      expect(jsonDecode(requests[2].data as String), {'before': 'msg_1'});

      await client.compactSession('ses_1', messageId: 'msg_c');
      expect(jsonDecode(requests[3].data as String), {
        'id': 'msg_c',
        'delivery': 'steer',
      });

      await client.deleteSession('ses_1');
      expect(requests[4].method, 'DELETE');
    });

    test('reads branch, status and diff within the location', () async {
      final adapter = FakeAdapter({
        '/api/vcs': FakeRoute.json({
          'data': {
            'branch': {'current': 'feature', 'default': 'main'},
          },
        }),
        '/api/vcs/status': FakeRoute.json({
          'data': [
            {
              'file': 'Sources/main.swift',
              'additions': 2,
              'deletions': 1,
              'status': 'modified',
            },
          ],
        }),
        '/api/vcs/diff': FakeRoute.json({
          'data': [
            {
              'file': 'Sources/main.swift',
              'patch': '@@ -1 +1 @@\n-a\n+b',
              'additions': 1,
              'deletions': 1,
              'status': 'modified',
            },
          ],
        }),
      });
      final client = clientFor(adapter);
      final branch = await client.vcsBranch(directory: '/repo');
      expect(branch.current, 'feature');
      expect(branch.defaultBranch, 'main');
      expect((await client.vcsStatus(directory: '/repo')).single.additions, 2);
      final diff = await client.vcsDiff(
        directory: '/repo',
        mode: DiffMode.branch,
      );
      expect(diff.single.patch, startsWith('@@'));
      final query = adapter.requests.last.queryParameters;
      expect(query['mode'], 'branch');
      expect(query['location[directory]'], '/repo');
    });

    test('lists MCP servers and toggles their connection', () async {
      final adapter = FakeAdapter({
        '/api/mcp': FakeRoute.json({
          'data': [
            {
              'name': 'tools',
              'status': {'status': 'connected'},
            },
            {
              'name': 'broken',
              'status': {'status': 'failed', 'error': 'spawn ENOENT'},
            },
          ],
        }),
        '/api/mcp/tools/disconnect': const FakeRoute(204, ''),
      });
      final client = clientFor(adapter);
      final servers = await client.listMcpServers(directory: '/repo');
      expect(servers.first.isConnected, isTrue);
      expect(servers.last.status, 'failed');
      expect(servers.last.error, 'spawn ENOENT');

      await client.setMcpConnected(
        'tools',
        connected: false,
        directory: '/repo',
      );
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, '/api/mcp/tools/disconnect');
    });
  });

  group('files, worktrees and attachments', () {
    test('lists, finds and reads files within the location', () async {
      final adapter = FakeAdapter({
        '/api/fs/list': FakeRoute.json({
          'location': {'directory': '/repo'},
          'data': [
            {'path': 'lib/', 'type': 'directory'},
            {'path': 'lib/main.dart', 'type': 'file'},
          ],
        }),
        '/api/fs/find': FakeRoute.json({
          'data': [
            {'path': 'lib/main.dart', 'type': 'file'},
          ],
        }),
        '/api/fs/read/lib/my%20file.dart': const FakeRoute(
          200,
          'let value = 1',
          contentType: 'text/plain',
        ),
        '/api/fs/read/logo.png': const FakeRoute(
          200,
          'PNG',
          contentType: 'image/png',
        ),
      });
      final client = clientFor(adapter);

      final entries = await client.listFiles(directory: '/repo', path: 'lib');
      expect(entries.first.isDirectory, isTrue);
      expect(entries.first.name, 'lib');
      expect(entries.last.name, 'main.dart');
      expect(adapter.requests.last.queryParameters['path'], 'lib');

      final found = await client.findFiles(directory: '/repo', query: 'main');
      expect(found.single.path, 'lib/main.dart');
      expect(adapter.requests.last.queryParameters['type'], 'file');

      final text = await client.readFile(
        directory: '/repo',
        path: 'lib/my file.dart',
      );
      expect(text.text, 'let value = 1');
      expect(
        adapter.requests.last.queryParameters['location[directory]'],
        '/repo',
      );
      final image = await client.readFile(directory: '/repo', path: 'logo.png');
      expect(image.isImage, isTrue);
      expect(image.text, isNull);
    });

    test('lists, creates and removes worktrees', () async {
      final removals = <Map<String, dynamic>>[];
      final adapter = FakeAdapter({
        '/api/worktree': (RequestOptions request) {
          switch (request.method) {
            case 'GET':
              return FakeRoute.json([
                {'directory': '/repo'},
                {'directory': '/copies/a', 'strategy': 'git'},
              ]);
            case 'POST':
              return FakeRoute.json({'directory': '/copies/topic'});
            default:
              final body =
                  jsonDecode(request.data as String) as Map<String, dynamic>;
              removals.add(body);
              return body['force'] == true
                  ? const FakeRoute(204, '')
                  : FakeRoute.json({
                      'name': 'WorktreeError',
                      'data': {
                        'message': 'Dirty checkout',
                        'forceRequired': true,
                      },
                    }, status: 400);
          }
        },
      });
      final client = clientFor(adapter);

      final worktrees = await client.listWorktrees('proj');
      expect(worktrees.first.isMain, isTrue);
      expect(worktrees.last.isManaged, isTrue);
      expect(worktrees.last.name, 'a');
      expect(adapter.requests.last.queryParameters, {'projectID': 'proj'});

      expect(
        await client.createWorktree('proj', name: 'topic'),
        '/copies/topic',
      );
      expect(jsonDecode(adapter.requests.last.data as String), {
        'projectID': 'proj',
        'name': 'topic',
      });

      await expectLater(
        client.removeWorktree('proj', '/copies/a'),
        throwsA(
          isA<WorktreeDirtyException>().having(
            (e) => e.message,
            'message',
            'Dirty checkout',
          ),
        ),
      );
      await client.removeWorktree('proj', '/copies/a', force: true);
      expect(removals.last, {
        'projectID': 'proj',
        'directory': '/copies/a',
        'force': true,
      });
    });

    test('sends attachments inline as data URLs', () async {
      late Map<String, dynamic> sent;
      final adapter = FakeAdapter({
        '/api/session/s1/prompt': (RequestOptions request) {
          sent = jsonDecode(request.data as String) as Map<String, dynamic>;
          return FakeRoute.json({
            'data': {'id': sent['id'], 'sessionID': 's1'},
          });
        },
      });
      final admission = await clientFor(adapter).sendPrompt(
        sessionId: 's1',
        messageId: 'msg_1',
        text: '',
        files: [
          PromptFile(
            name: 'a.png',
            mime: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      expect(admission, PromptAdmission.accepted);
      expect(sent['files'], [
        {'uri': 'data:image/png;base64,AQID', 'name': 'a.png'},
      ]);
    });
  });

  group('terminals', () {
    test('creates, resizes, lists and deletes terminals', () async {
      const pty = {
        'id': 'pty_1',
        'title': 'Terminal 1',
        'command': '/bin/zsh',
        'cwd': '/repo',
        'status': 'running',
        'pid': 42,
      };
      final adapter = FakeAdapter({
        '/api/pty': (RequestOptions request) => request.method == 'POST'
            ? FakeRoute.json({
                'location': {'directory': '/repo'},
                'data': pty,
              })
            : FakeRoute.json({
                'data': [
                  pty,
                  {...pty, 'id': 'pty_2', 'status': 'exited', 'exitCode': 130},
                ],
              }),
        '/api/pty/pty_1': (RequestOptions request) => request.method == 'PUT'
            ? FakeRoute.json({'data': pty})
            : const FakeRoute(204, ''),
      });
      final client = clientFor(adapter);

      final created = await client.createPty(directory: '/repo', title: 'New');
      expect(created.id, 'pty_1');
      expect(jsonDecode(adapter.requests.last.data as String), {
        'title': 'New',
      });
      expect(
        adapter.requests.last.queryParameters['location[directory]'],
        '/repo',
      );

      await client.resizePty('pty_1', directory: '/repo', rows: 24, cols: 80);
      expect(adapter.requests.last.method, 'PUT');
      expect(jsonDecode(adapter.requests.last.data as String), {
        'size': {'rows': 24, 'cols': 80},
      });

      final list = await client.listPtys(directory: '/repo');
      expect(list.last.isRunning, isFalse);
      expect(list.last.exitCode, 130);

      await client.deletePty('pty_1', directory: '/repo');
      expect(adapter.requests.last.method, 'DELETE');
    });

    test('builds the WebSocket address under the server base path', () {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com/relay/',
        username: 'user',
        password: 'password',
        dio: fakeDio(FakeAdapter({})),
      );
      final uri = client.ptySocketUri(
        'pty_1',
        directory: '/tmp/a b',
        cursor: 5,
      );
      expect(uri.scheme, 'wss');
      expect(uri.path, '/relay/api/pty/pty_1/connect');
      expect(uri.queryParameters, {
        'location[directory]': '/tmp/a b',
        'cursor': '5',
      });
      expect(client.socketHeaders, {
        'Authorization': 'Basic dXNlcjpwYXNzd29yZA==',
      });
    });
  });
}
