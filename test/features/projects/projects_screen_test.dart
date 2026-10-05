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
}
