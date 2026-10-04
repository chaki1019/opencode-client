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
  testWidgets('lists every model under its provider heading', (tester) async {
    final results = await _open(tester, [..._anthropic, ..._openai]);

    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('GPT'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    // Headings come before their own models.
    expect(
      tester.getTopLeft(find.text('Anthropic')).dy,
      lessThan(tester.getTopLeft(find.text('Sonnet')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Opus')).dy,
      lessThan(tester.getTopLeft(find.text('OpenAI')).dy),
    );

    await tester.tap(find.text('GPT'));
    await tester.pumpAndSettle();
    expect(results, [const ModelRef(providerID: 'openai', id: 'gpt')]);
  });

  testWidgets('the filter drops providers without a match', (tester) async {
    await _open(tester, [..._anthropic, ..._openai]);
    await tester.enterText(find.byType(TextField), 'opu');
    await tester.pumpAndSettle();
    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
    expect(find.text('OpenAI'), findsNothing);
    expect(find.text('GPT'), findsNothing);
  });

  testWidgets('the filter matches provider names', (tester) async {
    await _open(tester, [..._anthropic, ..._openai]);
    await tester.enterText(find.byType(TextField), 'openai');
    await tester.pumpAndSettle();
    expect(find.text('GPT'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await _open(tester, [..._anthropic, ..._openai]);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching models'), findsOneWidget);
  });
}
