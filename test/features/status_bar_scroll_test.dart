import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/status_bar_scroll.dart';

late TranscriptScrollController _list;

/// A transcript whose items vary in height, so the lazily estimated far
/// end is far off until the items are laid out.
Future<void> _pumpTranscript(
  WidgetTester tester, {
  VoidCallback? onArrived,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StatusBarScrollsToOldest(
        onArrived: onArrived,
        builder: (context, controller) {
          _list = controller;
          return Scaffold(
            body: PrimaryScrollController.none(
              child: ListView.builder(
                controller: controller,
                reverse: true,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: 101,
                itemBuilder: (context, i) =>
                    SizedBox(height: i < 10 ? 400 : 40, child: Text('item $i')),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// What [ScaffoldState.handleStatusBarTap] does once its hit test passes.
void _tapStatusBar(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold));
  final primary = PrimaryScrollController.of(context);
  expect(primary.hasClients, isTrue);
  unawaited(
    primary.animateTo(
      0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCirc,
    ),
  );
}

void main() {
  testWidgets('status bar tap scrolls to the oldest item without overshoot', (
    tester,
  ) async {
    var arrived = 0;
    await _pumpTranscript(tester, onArrived: () => arrived++);

    _tapStatusBar(tester);
    var overshoot = 0.0;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final p = _list.position;
      overshoot = [
        overshoot,
        p.pixels - p.maxScrollExtent,
      ].reduce((a, b) => a > b ? a : b);
      if (i < 50) expect(_list.scrollingToOldest, isTrue);
    }
    await tester.pumpAndSettle();

    expect(overshoot, 0);
    expect(_list.scrollingToOldest, isFalse);
    expect(_list.offset, _list.position.maxScrollExtent);
    expect(find.text('item 100'), findsOneWidget);
    expect(arrived, 1);
  });

  testWidgets('touching the list stops the scroll', (tester) async {
    var arrived = 0;
    await _pumpTranscript(tester, onArrived: () => arrived++);

    _tapStatusBar(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.text('item 0', skipOffstage: false),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(_list.scrollingToOldest, isFalse);
    expect(arrived, 0);
    expect(find.text('item 100'), findsNothing);
  });
}
