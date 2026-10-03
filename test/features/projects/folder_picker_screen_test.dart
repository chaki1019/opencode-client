import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/features/projects/folder_picker_screen.dart';
import 'package:opencode_mobile/features/projects/project_providers.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  const tree = {
    '/home/me': ['.config/', 'dev/', 'notes/'],
    '/home/me/dev': ['blog/', 'opencode-client/'],
    '/home': ['me/'],
  };

  Future<void> pumpPicker(WidgetTester tester) async {
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
          home: const FolderPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts at the server directory and hides dot folders', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(find.text('dev'), findsOneWidget);
    expect(find.text('.config'), findsNothing);

    await tester.tap(find.byKey(const Key('toggle-hidden')));
    await tester.pumpAndSettle();
    expect(find.text('.config'), findsOneWidget);
  });

  testWidgets('opens folders and goes back up', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.text('dev'));
    await tester.pumpAndSettle();
    expect(find.text('opencode-client'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('breadcrumbs')),
        matching: find.text('dev'),
      ),
      findsOneWidget,
    );

    // Back returns to the previous folder instead of leaving the picker.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsOneWidget);

    // A breadcrumb jumps up the tree.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('breadcrumbs')),
        matching: find.text('home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('me'), findsWidgets);
    expect(find.text('notes'), findsNothing);
  });

  testWidgets('jumps to a typed absolute path', (tester) async {
    await pumpPicker(tester);

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
