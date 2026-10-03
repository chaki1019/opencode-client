import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/status_bar_scroll.dart';

/// What [ScaffoldState.handleStatusBarTap] does once its hit test passes.
Future<void> _tapStatusBar(WidgetTester tester) async {
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('status bar tap scrolls a reversed list to its oldest item', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    late ScrollController list;
    await tester.pumpWidget(
      MaterialApp(
        home: StatusBarScrollsToOldest(
          builder: (context, controller) {
            list = controller;
            return Scaffold(
              body: PrimaryScrollController.none(
                child: ListView(
                  controller: controller,
                  reverse: true,
                  children: [
                    for (var i = 0; i < 50; i++)
                      SizedBox(height: 60, child: Text('item $i')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(list.offset, 0);

    await _tapStatusBar(tester);

    expect(list.offset, list.position.maxScrollExtent);
    expect(find.text('item 49'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
