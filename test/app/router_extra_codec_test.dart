import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opencode_mobile/app/router.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/core/models/session.dart';

const _project = Project(
  id: 'p1',
  directory: '/work/demo',
  name: 'demo-project',
  icon: ProjectIcon(color: 'blue'),
  time: ProjectTime(created: 1, updated: 2),
);

const _session = Session(
  id: 's1',
  projectID: 'p1',
  title: 'init',
  location: SessionLocation(directory: '/work/demo'),
  time: SessionTime(created: 1, updated: 2),
  model: ModelRef(providerID: 'opencode', id: 'big-pickle'),
  tokens: TokenUsage(input: 3, output: 4),
);

void main() {
  const codec = RouteExtraCodec();

  test('round-trips projects and sessions', () {
    expect(codec.decode(codec.encode(_project)), _project);
    expect(codec.decode(codec.encode(_session)), _session);
    expect(codec.decode(codec.encode(null)), isNull);
  });

  testWidgets('a pushed page keeps its project after a refresh', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/projects',
      extraCodec: codec,
      routes: [
        GoRoute(
          path: '/projects',
          builder: (_, _) => const Text('list'),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => Text((state.extra! as Project).directory),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/projects/p1', extra: _project);
    await tester.pumpAndSettle();

    // Connection changes re-run redirects, which re-reads the saved state.
    router.refresh();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('/work/demo'), findsOneWidget);
  });
}
