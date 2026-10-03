import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/features/projects/project_tools.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  const project = Project(id: 'p1', directory: '/home/me/dev/app');

  Future<void> pickTool(WidgetTester tester, String label) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('sessions'),
              actions: const [ProjectToolsButton(project: project)],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('project-tools')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final (label, empty) in [
    ('Git', '変更はありません'),
    ('ファイル', '空のフォルダです'),
    ('MCP', 'MCP サーバーは設定されていません'),
  ]) {
    testWidgets('$label opens in a bottom sheet over the page', (tester) async {
      await pickTool(tester, label);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
      expect(find.text(empty), findsOneWidget);
      expect(find.text('sessions'), findsOneWidget);
    });
  }

  testWidgets('terminal opens as a full page', (tester) async {
    await pickTool(tester, 'ターミナル');

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('ターミナル'), findsOneWidget);
    expect(find.text('sessions'), findsNothing);
  });
}
