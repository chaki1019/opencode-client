import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/catalog.dart';
import 'package:opencode_mobile/core/models/session.dart';
import 'package:opencode_mobile/features/chat/model_picker.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

const _anthropic = [
  ModelOption(
    providerID: 'anthropic',
    providerName: 'Anthropic',
    id: 'sonnet',
    name: 'Sonnet',
  ),
  ModelOption(
    providerID: 'anthropic',
    providerName: 'Anthropic',
    id: 'opus',
    name: 'Opus',
  ),
];
const _openai = [
  ModelOption(
    providerID: 'openai',
    providerName: 'OpenAI',
    id: 'gpt',
    name: 'GPT',
  ),
];

/// Opens the picker in a bottom sheet and records what it returns.
Future<List<ModelRef?>> _open(
  WidgetTester tester,
  List<ModelOption> models,
) async {
  final results = <ModelRef?>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
              await showModalBottomSheet<ModelRef>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    SizedBox(height: 500, child: ModelPicker(models: models)),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('drills down from provider to model', (tester) async {
    final results = await _open(tester, [..._anthropic, ..._openai]);

    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('2 models'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);

    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('GPT'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('OpenAI'), findsOneWidget);

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPT'));
    await tester.pumpAndSettle();
    expect(results, [const ModelRef(providerID: 'openai', id: 'gpt')]);
  });

  testWidgets('system back returns to the provider list', (tester) async {
    await _open(tester, [..._anthropic, ..._openai]);
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
  });

  testWidgets('a single provider shows its models directly', (tester) async {
    await _open(tester, _anthropic);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('only the model step has a search field', (tester) async {
    await _open(tester, [..._anthropic, ..._openai]);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'op');
    await tester.pumpAndSettle();
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
  });
}
