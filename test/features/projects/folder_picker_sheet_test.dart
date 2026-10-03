import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/features/projects/folder_picker_sheet.dart';
import 'package:opencode_mobile/features/projects/project_providers.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  const tree = {
    '/home/me': ['.config/', 'dev/', 'notes/'],
    '/home/me/dev': ['blog/', 'opencode-client/'],
    '/home': ['me/'],
  };

  final breadcrumbs = find.byKey(const Key('breadcrumbs'));

  Future<void> openSheet(WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverDirectoryProvider.overrideWith((ref) async => '/home/me'),
          subfoldersProvider.overrideWith(
            (ref, dir) async => [
              for (final p in tree[dir] ?? const <String>[])
                FsEntry(path: p, isDirectory: true),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => FolderPickerSheet.show(context),
                child: const Text('add'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts at the server directory and hides dot folders', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('dev'), findsOneWidget);
    expect(find.text('.config'), findsNothing);
    expect(find.text('..'), findsNothing);

    await tester.tap(find.byKey(const Key('toggle-hidden')));
    await tester.pumpAndSettle();
    expect(find.text('.config'), findsOneWidget);
  });

  testWidgets('moves between folders inside the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('dev'));
    await tester.pumpAndSettle();
    expect(find.text('opencode-client'), findsOneWidget);
    expect(
      find.descendant(of: breadcrumbs, matching: find.text('dev')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('folder-up')));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsOneWidget);

    await tester.tap(
      find.descendant(of: breadcrumbs, matching: find.text('home')),
    );
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsNothing);

    // However deep the browsing went, back closes the sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FolderPickerSheet), findsNothing);
    expect(find.text('add'), findsOneWidget);
  });

  testWidgets('closes with the close button', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('close-folder-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(FolderPickerSheet), findsNothing);
  });

  testWidgets('jumps to a typed absolute path', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('enter-path')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('folder-path')), 'dev');
    await tester.tap(find.byKey(const Key('confirm-folder-path')));
    await tester.pumpAndSettle();
    expect(find.text('絶対パスを入力してください'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('folder-path')),
      '/home/me/dev/',
    );
    await tester.tap(find.byKey(const Key('confirm-folder-path')));
    await tester.pumpAndSettle();
    expect(find.text('blog'), findsOneWidget);
  });
}
