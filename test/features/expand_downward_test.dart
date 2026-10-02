import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/expand_downward.dart';

Widget _accordion(String title) => ExpandDownward(
  builder: (context, onExpansionChanged) => ExpansionTile(
    onExpansionChanged: onExpansionChanged,
    title: Text(title),
    children: const [SizedBox(height: 300, child: Text('body'))],
  ),
);

Widget _list({required bool reverse}) => MaterialApp(
  home: Scaffold(
    body: ListView(
      reverse: reverse,
      children: [
        _accordion('newest'),
        for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text('$i')),
      ],
    ),
  ),
);

void main() {
  testWidgets('reversed list: opening keeps the header in place', (
    tester,
  ) async {
    await tester.pumpWidget(_list(reverse: true));
    final before = tester.getTopLeft(find.text('newest'));

    await tester.tap(find.text('newest'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
    expect(tester.getTopLeft(find.text('newest')), before);

    await tester.tap(find.text('newest'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
    expect(tester.getTopLeft(find.text('newest')), before);
  });

  testWidgets('normal list is left alone', (tester) async {
    await tester.pumpWidget(_list(reverse: false));
    final before = tester.getTopLeft(find.text('newest'));
    await tester.tap(find.text('newest'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('newest')), before);
  });
}
