import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/scroll_to_newest.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  late ScrollController controller;

  Future<void> pumpTranscript(WidgetTester tester) async {
    controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: controller,
                reverse: true,
                itemCount: 200,
                itemBuilder: (context, i) =>
                    SizedBox(height: i.isEven ? 300 : 40, child: Text('m$i')),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ScrollToNewestButton(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const Key('scroll-to-newest')),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('hidden at the newest end', (tester) async {
    await pumpTranscript(tester);
    expect(opacity(tester), 0);
  });

  testWidgets('appears when scrolled back and returns to the newest end', (
    tester,
  ) async {
    await pumpTranscript(tester);
    controller.jumpTo(20000);
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);

    await tester.tap(find.byKey(const Key('scroll-to-newest')));
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(find.text('m0'), findsOneWidget);
    expect(opacity(tester), 0);
  });
}
