import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/models/timeline.dart';
import 'package:opencode_mobile/features/chat/expand_downward.dart';
import 'package:opencode_mobile/features/chat/timeline_widgets.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

final _output = List.generate(30, (i) => 'line $i').join('\n');

/// A chat-like reversed list; bumping [tick] rebuilds just the list.
Widget _chat({bool reverse = true, ValueNotifier<int>? tick}) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ja'),
  home: Scaffold(
    body: ValueListenableBuilder(
      valueListenable: tick ?? ValueNotifier(0),
      builder: (context, tick, _) => ListView(
        reverse: reverse,
        // A fresh anchor every build, as in ChatScreen.
        physics: AnchoredScrollPhysics(anchor: ScrollAnchor()),
        children: [
          for (var i = 0; i < 3; i++) SizedBox(height: 80, child: Text('a$i')),
          ToolCallView(
            tool: ToolContent(
              id: 't',
              name: 'edit',
              status: ToolStatus.completed,
              output: _output,
            ),
          ),
          ReasoningView(
            text: List.generate(20, (i) => 'thought $i').join('\n'),
          ),
          for (var i = 0; i < 20; i++)
            SizedBox(height: 80, child: Text('b$i $tick')),
        ],
      ),
    ),
  ),
);

/// Taps [label] and checks its position on every frame of the animation.
Future<void> _toggleKeepsHeader(
  WidgetTester tester,
  String label, {
  Future<void> Function()? midway,
}) async {
  final header = find.text(label);
  final before = tester.getTopLeft(header);
  await tester.tap(header);
  for (var i = 0; i < 30; i++) {
    if (i == 5 && midway != null) {
      await midway();
    } else {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(header), before, reason: '$label, frame $i');
  }
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(header), before);
}

void main() {
  for (final scrolled in [false, true]) {
    testWidgets('reversed list keeps headers still (scrolled: $scrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(_chat());
      if (scrolled) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(150);
        await tester.pump();
      }
      for (final label in ['edit', '思考']) {
        await _toggleKeepsHeader(tester, label); // open
        await tester.pump(ExpandDownward.window);
        await _toggleKeepsHeader(tester, label); // close
        await tester.pump(ExpandDownward.window);
      }
    });
  }

  testWidgets('a rebuild mid-animation keeps the header still', (tester) async {
    final tick = ValueNotifier(0);
    await tester.pumpWidget(_chat(tick: tick));
    await _toggleKeepsHeader(
      tester,
      'edit',
      midway: () {
        tick.value++;
        return tester.pump(const Duration(milliseconds: 16));
      },
    );
  });

  testWidgets('normal list is left alone', (tester) async {
    await tester.pumpWidget(_chat(reverse: false));
    await _toggleKeepsHeader(tester, 'edit');
  });
}
