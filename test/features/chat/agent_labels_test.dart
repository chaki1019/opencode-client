import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/chat/agent_labels.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/l10n/app_localizations_ja.dart';

void main() {
  test('capitalizes agent ids', () {
    expect(agentDisplayName('build'), 'Build');
    expect(agentDisplayName('plan'), 'Plan');
    expect(agentDisplayName(''), '');
  });

  test('built-in agents use the documented description', () {
    final en = AppLocalizationsEn();
    final ja = AppLocalizationsJa();
    expect(agentDescription(en, 'build', 'server'), en.agentBuildDescription);
    expect(agentDescription(ja, 'plan', 'server'), ja.agentPlanDescription);
    expect(agentDescription(en, 'custom', 'server'), 'server');
    expect(agentDescription(en, 'custom', null), isNull);
  });
}
