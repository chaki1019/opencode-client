/// An agent the session can run as (`GET /api/agent`).
class AgentInfo {
  const AgentInfo({
    required this.id,
    this.description,
    this.mode,
    this.hidden = false,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
    id: json['id'] as String,
    description: json['description'] as String?,
    mode: json['mode'] as String?,
    hidden: json['hidden'] == true,
  );

  final String id;
  final String? description;

  /// `primary`, `subagent` or `all`. Subagents are invoked by other agents
  /// and are not offered as a session's main agent.
  final String? mode;
  final bool hidden;

  bool get isSelectable => !hidden && mode != 'subagent';
}

/// A model offered by an enabled provider (`GET /api/provider` +
/// `GET /api/model`).
class ModelOption {
  const ModelOption({
    required this.providerID,
    required this.providerName,
    required this.id,
    required this.name,
    this.variants = const [],
    this.contextLimit,
  });

  final String providerID;
  final String providerName;
  final String id;
  final String name;

  /// Variant IDs such as reasoning-effort levels.
  final List<String> variants;

  /// The most tokens the model can hold in its context window.
  final int? contextLimit;
}
