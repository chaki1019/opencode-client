import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/features/projects/project_providers.dart';
import 'package:opencode_mobile/features/projects/projects_screen.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWithValue(
            const AsyncData(
              ProjectBootstrap(
                projects: [Project(id: 'p1', directory: '/srv/app')],
              ),
            ),
          ),
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

  testWidgets('shows a Projects section with an add button', (tester) async {
    await pumpScreen(tester);

    final add = find.byKey(const Key('add-project'));
    final row = find.ancestor(of: add, matching: find.byType(Row)).first;
    final header = tester.getRect(add);
    final label = tester.getRect(
      find.descendant(of: row, matching: find.text('プロジェクト')),
    );
    expect(label.center.dy, closeTo(header.center.dy, 1));
    expect(label.left, lessThan(header.left));
    expect(
      find.descendant(
        of: find.byKey(const Key('project-list')),
        matching: find.text('app'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('asks for an absolute folder path', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('add-project')));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを追加'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('project-folder')), 'src/app');
    await tester.tap(find.byKey(const Key('confirm-add-project')));
    await tester.pumpAndSettle();
    expect(find.text('絶対パスを入力してください'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトを追加'), findsNothing);
  });
}
