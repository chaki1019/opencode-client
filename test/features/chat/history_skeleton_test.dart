import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/paging.dart';
import 'package:opencode_mobile/features/chat/history_skeleton.dart';
import 'package:opencode_mobile/features/chat/timeline_widgets.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

Widget _indicator(PagedItems<Object?> paged) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ja'),
  home: Scaffold(
    body: ListView(
      reverse: true,
      children: [
        const SizedBox(height: 200, child: Text('newest')),
        OlderHistoryIndicator(paged: paged, onRetry: () {}),
      ],
    ),
  ),
);

void main() {
  testWidgets('shows a skeleton while older history remains', (tester) async {
    await tester.pumpWidget(
      _indicator(const PagedItems(items: [], nextCursor: 'c')),
    );
    await tester.pump();
    expect(find.byType(HistorySkeleton), findsOneWidget);
    final height = tester.getSize(find.byType(HistorySkeleton)).height;
    expect(height, closeTo(600 * HistorySkeleton.heightFactor, 0.1));
  });

  testWidgets('shows nothing once the history is complete', (tester) async {
    await tester.pumpWidget(_indicator(const PagedItems(items: [])));
    expect(find.byType(HistorySkeleton), findsNothing);
  });

  testWidgets('offers a retry instead of the skeleton after a failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _indicator(
        PagedItems(
          items: const [],
          nextCursor: 'c',
          loadMoreError: Exception(),
        ),
      ),
    );
    expect(find.byType(HistorySkeleton), findsNothing);
    expect(find.byType(TextButton), findsOneWidget);
  });
}
