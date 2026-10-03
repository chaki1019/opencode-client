import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/pull_up_to_refresh.dart';

Widget _list(ScrollPhysics physics, VoidCallback onRefresh) => MaterialApp(
  home: Scaffold(
    body: PullUpToRefresh(
      onRefresh: () async => onRefresh(),
      child: ListView(
        reverse: true,
        physics: AlwaysScrollableScrollPhysics(parent: physics),
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 60, child: Text('item $i')),
        ],
      ),
    ),
  ),
);

void main() {
  for (final (name, physics) in [
    ('clamping', const ClampingScrollPhysics()),
    ('bouncing', const BouncingScrollPhysics()),
  ]) {
    group(name, () {
      testWidgets('pulling up at the newest end refreshes', (tester) async {
        var refreshed = 0;
        await tester.pumpWidget(_list(physics, () => refreshed++));
        await tester.drag(find.text('item 0'), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(refreshed, 1);
      });

      testWidgets('a short pull does not refresh', (tester) async {
        var refreshed = 0;
        await tester.pumpWidget(_list(physics, () => refreshed++));
        await tester.drag(find.text('item 0'), const Offset(0, -20));
        await tester.pumpAndSettle();
        expect(refreshed, 0);
        expect(find.byKey(const Key('pull-up-indicator')), findsNothing);
      });

      testWidgets('pulling down at the oldest end does not refresh', (
        tester,
      ) async {
        var refreshed = 0;
        await tester.pumpWidget(_list(physics, () => refreshed++));
        await tester.drag(find.text('item 0'), const Offset(0, 5000));
        await tester.pumpAndSettle();
        await tester.drag(find.text('item 29'), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(refreshed, 0);
      });
    });
  }
}
