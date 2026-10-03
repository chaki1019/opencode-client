import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/features/git/git_providers.dart';
import 'package:opencode_mobile/features/git/git_screen.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('keeps the branch labels while the other mode loads', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    final branchDiff = Completer<GitSnapshot>();
    const branch = VcsBranch(current: 'feature/x', defaultBranch: 'main');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gitProvider.overrideWith(
            (ref, key) => key.$2 == DiffMode.working
                ? Future.value(const GitSnapshot(branch: branch, files: []))
                : branchDiff.future,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GitScreen(
            project: Project(id: 'p', directory: '/x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('mainとの差分'), findsOneWidget);

    await tester.tap(find.text('mainとの差分'));
    await tester.pump();
    expect(find.text('mainとの差分'), findsOneWidget);
    expect(find.text('feature/x'), findsOneWidget);

    branchDiff.complete(const GitSnapshot(branch: branch, files: []));
    await tester.pumpAndSettle();
  });
}
