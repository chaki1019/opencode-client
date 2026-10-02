/// Display name for an agent id: `build` → `Build`.
String agentDisplayName(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// Descriptions of OpenCode's built-in agents, following
/// https://opencode.ai/docs/agents/. Other agents keep the server's text.
const _builtInDescriptions = {
  'build':
      'すべてのツールが有効なデフォルトのエージェントです。'
      'ファイル操作やシステムコマンドを自由に使う、通常の開発作業向けです。',
  'plan':
      '計画と分析のための制限付きエージェントです。'
      '権限設定により、意図しない変更を防ぎます。',
};

String? agentDescription(String id, String? serverDescription) =>
    _builtInDescriptions[id] ?? serverDescription;
