import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/core/storage/hidden_projects_store.dart';
import 'package:opencode_mobile/features/projects/project_providers.dart';
import 'package:opencode_mobile/features/projects/projects_screen.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

const _server = 'http://example.test:4096';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Project> projects = const [Project(id: 'p1', directory: '/srv/app')],
  }) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWithValue(
            AsyncData(ProjectBootstrap(projects: projects)),
          ),
          serverUrlProvider.overrideWithValue(_server),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a Projects section and a FAB to add one', (tester) async {
    await pumpScreen(tester);

    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('プロジェクト')),
      findsOneWidget,
    );
    final add = find.byKey(const Key('add-project'));
    expect(tester.widget(add), isA<FloatingActionButton>());
    // The header no longer has a "+" of its own.
    expect(find.widgetWithIcon(IconButton, Icons.add), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('project-list')),
        matching: find.text('app'),
      ),
      findsOneWidget,
    );
  });

  Finder projectRow(String name) => find.descendant(
    of: find.byKey(const Key('project-list')),
    matching: find.text(name),
  );

  const two = [
    Project(id: 'p1', directory: '/srv/app'),
    Project(id: 'p2', directory: '/srv/old'),
  ];

  testWidgets('swiping a project takes it off the list and can be undone', (
    tester,
  ) async {
    await pumpScreen(tester, projects: two);

    await tester.drag(projectRow('old'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsNothing);
    expect(projectRow('app'), findsOneWidget);
    expect(find.text('「old」を一覧から外しました'), findsOneWidget);
    expect(await HiddenProjectsStore().load(), {
      _server: {'/srv/old'},
    });

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsOneWidget);
    expect(await HiddenProjectsStore().load(), isEmpty);
  });

  testWidgets('long-pressing a project offers to take it off the list', (
    tester,
  ) async {
    await pumpScreen(tester, projects: two);

    await tester.longPress(projectRow('old'));
    await tester.pumpAndSettle();
    expect(
      find.text('サーバー上のプロジェクトとセッションはそのまま残ります。「＋」から開き直すと一覧に戻ります。'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('project-hide')));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsNothing);
  });

  testWidgets('projects hidden on another server stay listed', (tester) async {
    await HiddenProjectsStore().save({
      _server: {'/srv/old'},
      'http://other.test:4096': {'/srv/app'},
    });
    await pumpScreen(tester, projects: two);

    expect(projectRow('app'), findsOneWidget);
    expect(projectRow('old'), findsNothing);
  });
}
