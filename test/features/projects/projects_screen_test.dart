import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/core/storage/project_directories_store.dart';
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

  testWidgets('two projects in the same folder are both listed', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      projects: const [
        Project(id: 'global', directory: '/'),
        Project(id: 'p1', directory: '/'),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('project-list')),
        matching: find.byType(Dismissible),
      ),
      findsNWidgets(2),
    );
  });

  // Hidden rows stay in the list folded to nothing, so only rows that can
  // be tapped count as listed.
  Finder projectRow(String name) => find
      .descendant(
        of: find.byKey(const Key('project-list')),
        matching: find.text(name),
      )
      .hitTestable();

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
    expect(await ProjectDirectoriesStore.hidden().load(), {
      _server: {'/srv/old'},
    });

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsOneWidget);
    expect(await ProjectDirectoriesStore.hidden().load(), isEmpty);
  });

  testWidgets('long-pressing a project offers to take it off the list', (
    tester,
  ) async {
    await pumpScreen(tester, projects: two);

    await tester.longPress(projectRow('old'));
    await tester.pumpAndSettle();
    expect(
      find.text('サーバー上のプロジェクトとセッションはそのまま残ります。一覧右上の目のボタンから戻せます。'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('project-hide')));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsNothing);
  });

  testWidgets('projects hidden on another server stay listed', (tester) async {
    await ProjectDirectoriesStore.hidden().save({
      _server: {'/srv/old'},
      'http://other.test:4096': {'/srv/app'},
    });
    await pumpScreen(tester, projects: two);

    expect(projectRow('app'), findsOneWidget);
    expect(projectRow('old'), findsNothing);
  });

  testWidgets('show all lists hidden projects and the eye switches them', (
    tester,
  ) async {
    await ProjectDirectoriesStore.hidden().save({
      _server: {'/srv/old'},
    });
    await pumpScreen(tester, projects: two);
    expect(projectRow('old'), findsNothing);
    // The badge counts the hidden project.
    expect(
      find.descendant(
        of: find.byKey(const Key('show-all-projects')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('show-all-projects')));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsOneWidget);
    expect(projectRow('app'), findsOneWidget);
    expect(find.byKey(const Key('project-visibility')), findsNWidgets(2));

    // Shows the hidden one again.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('old'),
          matching: find.byType(ListTile),
        ),
        matching: find.byKey(const Key('project-visibility')),
      ),
    );
    await tester.pumpAndSettle();
    expect(await ProjectDirectoriesStore.hidden().load(), isEmpty);

    // Hides the other one.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('app'),
          matching: find.byType(ListTile),
        ),
        matching: find.byKey(const Key('project-visibility')),
      ),
    );
    await tester.pumpAndSettle();
    expect(await ProjectDirectoriesStore.hidden().load(), {
      _server: {'/srv/app'},
    });
    // Still listed while showing all.
    expect(projectRow('app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('show-all-projects')));
    await tester.pumpAndSettle();
    expect(projectRow('app'), findsNothing);
    expect(projectRow('old'), findsOneWidget);
  });

  testWidgets('pinned projects come first', (tester) async {
    const projects = [
      Project(
        id: 'p1',
        directory: '/srv/new',
        time: ProjectTime(created: 2, updated: 2),
      ),
      Project(
        id: 'p2',
        directory: '/srv/old',
        time: ProjectTime(created: 1, updated: 1),
      ),
    ];
    await pumpScreen(tester, projects: projects);
    double top(String name) => tester.getTopLeft(projectRow(name)).dy;
    expect(top('new'), lessThan(top('old')));
    expect(find.byKey(const Key('project-pinned')), findsNothing);

    await tester.longPress(projectRow('old'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-pin')));
    await tester.pumpAndSettle();
    expect(top('old'), lessThan(top('new')));
    expect(find.byKey(const Key('project-pinned')), findsOneWidget);
    expect(await ProjectDirectoriesStore.pinned().load(), {
      _server: {'/srv/old'},
    });

    await tester.longPress(projectRow('old'));
    await tester.pumpAndSettle();
    expect(find.text('ピン留めを外す'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-pin')));
    await tester.pumpAndSettle();
    expect(top('new'), lessThan(top('old')));
    expect(await ProjectDirectoriesStore.pinned().load(), isEmpty);
  });

  testWidgets('swiping a project right pins it and again unpins it', (
    tester,
  ) async {
    await pumpScreen(tester, projects: two);

    await tester.drag(projectRow('old'), const Offset(600, 0));
    await tester.pumpAndSettle();
    // Pinning keeps the row on the list.
    expect(projectRow('old'), findsOneWidget);
    expect(find.byKey(const Key('project-pinned')), findsOneWidget);
    expect(await ProjectDirectoriesStore.pinned().load(), {
      _server: {'/srv/old'},
    });
    expect(await ProjectDirectoriesStore.hidden().load(), isEmpty);

    await tester.drag(projectRow('old'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-pinned')), findsNothing);
    expect(await ProjectDirectoriesStore.pinned().load(), isEmpty);
  });

  testWidgets('while showing all, a right swipe still pins', (tester) async {
    await pumpScreen(tester, projects: two);
    await tester.tap(find.byKey(const Key('show-all-projects')));
    await tester.pumpAndSettle();

    await tester.drag(projectRow('old'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(await ProjectDirectoriesStore.pinned().load(), {
      _server: {'/srv/old'},
    });
    // A left swipe hides nothing here; the eye does that.
    await tester.drag(projectRow('old'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(projectRow('old'), findsOneWidget);
    expect(await ProjectDirectoriesStore.hidden().load(), isEmpty);
  });
}
