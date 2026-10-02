import '../../l10n/l10n.dart';

/// Display name for an agent id: `build` → `Build`.
String agentDisplayName(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// Built-in agents use the wording of https://opencode.ai/docs/agents/;
/// other agents keep the server's text.
String? agentDescription(
  AppLocalizations l10n,
  String id,
  String? serverDescription,
) => switch (id) {
  'build' => l10n.agentBuildDescription,
  'plan' => l10n.agentPlanDescription,
  _ => serverDescription,
};
